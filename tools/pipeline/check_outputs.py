"""Self-check of the pipeline outputs against invariants and the Streif research.

Exits non-zero on failure. Run as the last pipeline step.
"""
from __future__ import annotations

import sys

import numpy as np

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
    h = np.fromfile(out / core["file"], dtype="<f4")
    check(h.size == core["width"] * core["height"], f"height.r32 size {h.size}")
    check(bool(np.isfinite(h).all()), "height.r32 has no NaN")
    fh = np.fromfile(out / far["file"], dtype="<f4")
    check(fh.size == far["width"] * far["height"], f"far_height.r32 size {fh.size}")
    check(bool(np.isfinite(fh).all()), "far_height.r32 has no NaN")
    check(core["width"] % config.TERRAIN3D_REGION_M == 0, "core aligned to Terrain3D regions")

    # world mapping of the known start point
    line = np.asarray(read_json(out / "line.json")["points"])
    sx = START_EN[0] - meta["origin_e0"]
    sz = -(START_EN[1] - meta["origin_n0"])
    d0 = float(np.hypot(line[0, 0] - sx, line[0, 2] - sz))
    check(d0 < 5.0, f"line start maps to known start point (offset {d0:.2f} m)")
    h2 = h.reshape(core["height"], core["width"])
    col, row = int(sx / core["res_m"]), int(core["height"] + sz / core["res_m"])
    check(abs(float(h2[row, col]) - START_ALT) < 15, f"height at start {h2[row, col]:.1f} m (~{START_ALT})")
    # far grid must agree with the core grid where they overlap (same mapping)
    fcol = int((sx - far["world_min_x"]) / far["res_m"])
    frow = int((sz - far["world_min_z"]) / far["res_m"])
    fh2 = fh.reshape(far["height"], far["width"])
    check(abs(float(fh2[frow, fcol]) - float(h2[row, col])) < 10, "far ring height matches core at start")

    st = read_json(out / "line_stats.json")
    check(abs(st["start_alt_m"] - START_ALT) < 15, f"start altitude {st['start_alt_m']}")
    check(abs(st["finish_alt_m"] - FINISH_ALT) < 10, f"finish altitude {st['finish_alt_m']}")
    check(abs(st["drop_m"] - DROP) / DROP < 0.03, f"vertical drop {st['drop_m']} (±3 %)")
    check(abs(st["length_3d_m"] - LENGTH_OFFICIAL) / LENGTH_OFFICIAL < 0.05,
          f"3D length {st['length_3d_m']} (±5 % of {LENGTH_OFFICIAL})")
    check(24 <= st["mean_gradient_pct"] <= 30, f"mean gradient {st['mean_gradient_pct']} %")
    check(st["max_gradient_10m_pct"] >= 65, f"max gradient {st['max_gradient_10m_pct']} % (≥65)")

    for f in ("trees.bin", "splat.png", "colormap.jpg", "sections.json"):
        check((out / f).exists(), f"{f} exists")
    if (out / "trees.bin").exists():
        n = (out / "trees.bin").stat().st_size // 12
        check(n == read_json(out / "trees_meta.json")["count"], f"trees.bin count {n}")
    print("CHECK", "FAILED" if fails else "PASSED")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
