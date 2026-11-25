"""Self-check of the pipeline outputs against invariants and the Streif research.

Exits non-zero on failure. Run as the last pipeline step.
"""
from __future__ import annotations

import sys

import numpy as np
from PIL import Image

import config
from common import read_json

# Reference values (docs/streif-research.md, docs/data-sources.md)
START_EN = (-72570.0, 254617.0)  # first OSM race-line node, EPSG:31255
START_ALT, FINISH_ALT, DROP = 1665.0, 805.0, 860.0
LENGTH_OFFICIAL = 3312.0


def main() -> int:
    fails: list[str] = []

    def check(cond: bool, msg: str) -> None:
        print(("  ok   " if cond else "  FAIL ") + msg)
        if not cond:
            fails.append(msg)

    out = config.OUT
    meta = read_json(out / "meta.json")
    core, far = meta["core"], meta["far"]
    w, d = core["width"], core["height"]
    h = np.fromfile(out / core["file"], dtype="<f4")
    check(h.size == w * d, f"height.r32 size {h.size}")
    check(bool(np.isfinite(h).all()), "height.r32 has no NaN")
    for ring in ("far", "horizon"):
        rg = meta[ring]
        rh = np.fromfile(out / rg["file"], dtype="<f4")
        check(rh.size == rg["width"] * rg["height"] and bool(np.isfinite(rh).all()), f"{ring} heights")
        check(Image.open(out / rg["color"]).size == (rg["width"], rg["height"]), f"{ring} colour map size")
        check(Image.open(out / rg["valid"]).size == (rg["width"], rg["height"]), f"{ring} valid mask size")
        check(rg["world_min_x"] % config.TERRAIN3D_REGION_M == 0, f"{ring} region-aligned")
    fh = np.fromfile(out / far["file"], dtype="<f4")
    check(fh.size == far["width"] * far["height"], f"far_height.r32 size {fh.size}")
    check(bool(np.isfinite(fh).all()), "far_height.r32 has no NaN")
    check(w % config.TERRAIN3D_REGION_M == 0 and d % config.TERRAIN3D_REGION_M == 0,
          "core aligned to Terrain3D regions")
    check(core["world_min_x"] == 0 and core["world_min_z"] == -d * core["res_m"],
          "core vertex (0,0) at (0, -size_z)")
    check(far["world_min_x"] % config.TERRAIN3D_REGION_M == 0 and far["world_min_z"] % config.TERRAIN3D_REGION_M == 0,
          "far grid region-aligned with the core")
    ctrl = np.fromfile(out / "control.r32", dtype="<u4")
    check(ctrl.size == w * d, "control.r32 matches core grid")
    check(int(((ctrl >> 27) & 31).max()) <= 3 and int((ctrl & 1).max()) == 0, "control ids 0..3, autoshader off")
    check(Image.open(out / "colormap.jpg").size == (w, d), "colormap matches core grid")

    # world mapping of the known start point (vertex convention)
    line = np.asarray(read_json(out / "line.json")["points"])
    sx = START_EN[0] - meta["origin_e0"]
    sz = -(START_EN[1] - meta["origin_n0"])
    d0 = float(np.hypot(line[0, 0] - sx, line[0, 2] - sz))
    check(d0 < 5.0, f"line start maps to known start point (offset {d0:.2f} m)")
    h2 = h.reshape(d, w)
    col = int(round((sx - core["world_min_x"]) / core["res_m"]))
    row = int(round((sz - core["world_min_z"]) / core["res_m"]))
    check(abs(float(h2[row, col]) - START_ALT) < 15, f"height at start {h2[row, col]:.1f} m (~{START_ALT})")
    fcol = int(round((sx - far["world_min_x"]) / far["res_m"]))
    frow = int(round((sz - far["world_min_z"]) / far["res_m"]))
    fh2 = fh.reshape(far["height"], far["width"])
    check(abs(float(fh2[frow, fcol]) - float(h2[row, col])) < 5, "far ring height matches core at start")
    # line y lies on the heightmap
    li = np.clip(np.round(line[:, 0]).astype(int), 0, w - 1)
    lr = np.clip(np.round(line[:, 2] - core["world_min_z"]).astype(int), 0, d - 1)
    check(float(np.percentile(np.abs(h2[lr, li] - line[:, 1]), 95)) < 1.0, "line y on the heightmap (p95 < 1 m)")

    st = read_json(out / "line_stats.json")
    check(abs(st["start_alt_m"] - START_ALT) < 15, f"start altitude {st['start_alt_m']}")
    check(abs(st["finish_alt_m"] - FINISH_ALT) < 10, f"finish altitude {st['finish_alt_m']}")
    check(abs(st["drop_m"] - DROP) / DROP < 0.03, f"vertical drop {st['drop_m']} (±3 %)")
    check(abs(st["length_3d_m"] - LENGTH_OFFICIAL) / LENGTH_OFFICIAL < 0.05,
          f"3D length {st['length_3d_m']} (±5 % of {LENGTH_OFFICIAL})")
    check(24 <= st["mean_gradient_pct"] <= 30, f"mean gradient {st['mean_gradient_pct']} %")
    check(st["max_gradient_10m_pct"] >= 65, f"max gradient {st['max_gradient_10m_pct']} % (≥65)")
    # piste shaping (process_shaping.py, jumps.json)
    jumps = read_json(out / "jumps.json")["jumps"]
    check(len(st.get("shaped", [])) == len(jumps) >= 4, f"{len(jumps)} modelled jumps baked in")
    lo, hi = st.get("shaping_offset_range_m", [99, 99])
    check(-8.0 <= lo <= 0.0 <= hi <= 8.0, f"shaping offsets {lo}..{hi} m (|dh| <= 8 m)")
    check(st["max_gradient_10m_pct"] >= 80 and st["max_gradient_10m_at_s"] < 260,
          f"Mausefalle steepness {st['max_gradient_10m_pct']} % at s={st['max_gradient_10m_at_s']} (>= 80 %)")
    secs = read_json(out / "sections.json")["sections"]
    check(len(secs) == 15 and all(a["s"] <= b["s"] for a, b in zip(secs, secs[1:])), "15 sections in order")

    trees = np.fromfile(out / "trees.bin", "<f4").reshape(-1, 3)
    check(len(trees) == read_json(out / "trees_meta.json")["count"], f"trees.bin count {len(trees)}")
    check(bool((trees[:, 0] >= 0).all() and (trees[:, 0] <= w - 1).all()
               and (trees[:, 1] >= -d).all() and (trees[:, 1] <= -1).all()), "trees inside core")
    b = read_json(out / "buildings.json")["buildings"]
    check(len(b) > 500, f"buildings.json {len(b)} buildings")
    pts = np.asarray([p for bb in b for p in bb["points"]])
    check(bool(np.isfinite(pts).all()) and all(bb["height_m"] >= 2.5 for bb in b), "building geometry sane")
    print("CHECK", "FAILED" if fails else "PASSED")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
