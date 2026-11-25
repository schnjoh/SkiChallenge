"""Build the game heightmaps, race line and section table.

Inputs:  data/raw/terrain/*.tif, data/raw/derived/{line_31255,extent}.json
Outputs (game/data/streif/):
  height.r32      core snow-surface heights, float32 LE, row 0 = north, cell centres
  far_height.r32  5 m far ring (DGM), same conventions
  meta.json       grid definitions + world mapping + provenance
  line.json       race line in Godot coordinates (x, y, z) with distance s
  sections.json   named sections with s, width
  line_stats.json measured length / drop / gradients (compared to research in phase 2)
Intermediate (data/raw/derived/): dgm_core_05.npy, dom_core_05.npy (0.5 m, for trees)
"""
from __future__ import annotations

import datetime as dt

import numpy as np
from rasterio.warp import Resampling
from scipy import ndimage

import config
from common import read_json, write_json
from geo import (distance_to_polyline, fill_nodata, mosaic_to_grid, nearest_line_index,
                 resample_polyline, sample_bilinear, smooth_polyline, write_r32)

DERIVED = config.RAW / "derived"
TERRAIN = config.RAW / "terrain"


def build_line(dgm: np.ndarray, core: dict) -> tuple[np.ndarray, np.ndarray, list[dict]]:
    src = read_json(DERIVED / "line_31255.json")
    raw = np.asarray(src["points"], float)
    pts = resample_polyline(raw, config.LINE_SPACING_M)
    pts = smooth_polyline(pts, config.LINE_SMOOTH_SIGMA_M / config.LINE_SPACING_M)
    pts = resample_polyline(pts, config.LINE_SPACING_M)
    h = sample_bilinear(dgm, core, pts[:, 0], pts[:, 1])
    s = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
    # cut at the finish: first point below FINISH_ALTITUDE_M in the last third
    below = np.where((h <= config.FINISH_ALTITUDE_M) & (s > s[-1] * 0.66))[0]
    if len(below):
        cut = int(below[0]) + 1
        pts, h, s = pts[:cut], h[:cut], s[:cut]
    named = []
    for p in src["named"]:
        d = np.hypot(pts[:, 0] - p["e"], pts[:, 1] - p["n"])
        i = int(np.argmin(d))
        named.append({"name": p["name"], "s": float(s[i]), "index": i, "offset_m": float(d[i])})
    named.sort(key=lambda x: x["s"])
    return pts, h, named


def section_widths(named: list[dict], n_pts: int) -> np.ndarray:
    w = np.full(n_pts, config.SECTION_WIDTHS_M.get("Start", config.PISTE_DEFAULT_WIDTH_M))
    for p in named:
        w[p["index"]:] = config.SECTION_WIDTHS_M.get(p["name"], config.PISTE_DEFAULT_WIDTH_M)
    # smooth width transitions over ~40 m
    return ndimage.gaussian_filter1d(w, 20.0 / config.LINE_SPACING_M, mode="nearest")


def gradient_stats(s: np.ndarray, h: np.ndarray, window_m: float) -> tuple[float, float]:
    """Max downhill gradient over a window (fraction) and the s where it occurs."""
    best, at = 0.0, 0.0
    j = 0
    for i in range(len(s)):
        while j < len(s) and s[j] - s[i] < window_m:
            j += 1
        if j >= len(s):
            break
        g = (h[i] - h[j]) / (s[j] - s[i])
        if g > best:
            best, at = g, float(s[i])
    return best, at


def main() -> None:
    ext = read_json(DERIVED / "extent.json")
    core, far = ext["core"], ext["far"]
    crs = config.CRS_PROJECT
    core05 = dict(core, res=0.5)

    print("[terrain] mosaicking 0.5 m DGM/DOM")
    dgm05 = fill_nodata(mosaic_to_grid(sorted(TERRAIN.glob("dgm_core_*.tif")), core05, crs,
                                       Resampling.nearest))
    dom05 = fill_nodata(mosaic_to_grid(sorted(TERRAIN.glob("dom_core_*.tif")), core05, crs,
                                       Resampling.nearest))
    dom05 = np.maximum(dom05, dgm05)
    np.save(DERIVED / "dgm_core_05.npy", dgm05.astype(np.float32))
    np.save(DERIVED / "dom_core_05.npy", dom05.astype(np.float32))

    print("[terrain] resampling to 1 m")
    dgm = fill_nodata(mosaic_to_grid(sorted(TERRAIN.glob("dgm_core_*.tif")), core, crs,
                                     Resampling.average))

    pts, h_line, named = build_line(dgm, core)
    widths = section_widths(named, len(pts))
    dist = distance_to_polyline(core, pts)
    near = nearest_line_index(core, pts)
    half_w = widths[near] / 2.0
    np.save(DERIVED / "corridor_dist.npy", (dist - half_w).astype(np.float32))

    # Snow surface: smooth the summer micro relief inside the piste corridor (soft 10 m edge).
    smooth = ndimage.gaussian_filter(dgm, config.SNOW_SMOOTH_SIGMA_M / core["res"])
    wgt = np.clip((half_w + 10.0 - dist) / 10.0, 0.0, 1.0)
    height = (dgm * (1.0 - wgt) + smooth * wgt + config.SNOW_DEPTH_M).astype(np.float32)

    out = config.OUT
    write_r32(out / "height.r32", height)
    print(f"[terrain] height.r32 {height.shape} {height.min():.1f}..{height.max():.1f} m")

    print("[terrain] far ring")
    far_h = fill_nodata(mosaic_to_grid(sorted(TERRAIN.glob("dgm_far_*.tif")), far, crs,
                                       Resampling.average)).astype(np.float32)
    write_r32(out / "far_height.r32", far_h)

    # Race line in Godot coordinates on the snow surface.
    y = sample_bilinear(height, core, pts[:, 0], pts[:, 1])
    x = pts[:, 0] - core["e0"]
    z = -(pts[:, 1] - core["n0"])
    s = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
    s3 = np.concatenate([[0.0], np.cumsum(np.sqrt(np.diff(x) ** 2 + np.diff(z) ** 2 + np.diff(y) ** 2))])
    write_json(out / "line.json", {
        "source": f"OpenStreetMap relation {config.OSM_RELATION_ID} (ODbL), smoothed",
        "spacing_m": config.LINE_SPACING_M,
        "points": [[round(float(a), 3), round(float(b), 3), round(float(c), 3), round(float(d), 2)]
                   for a, b, c, d in zip(x, y, z, s)],
        "fields": ["x", "y", "z", "s"],
    })
    write_json(out / "sections.json", {
        "note": "Editable. s = horizontal distance from start along line.json (m).",
        "sections": [{"name": "Start", "s": 0.0, "width_m": config.SECTION_WIDTHS_M["Start"],
                      "osm_offset_m": 0.0}] + [{"name": p["name"], "s": round(p["s"], 1),
                      "width_m": config.SECTION_WIDTHS_M.get(p["name"], config.PISTE_DEFAULT_WIDTH_M),
                      "osm_offset_m": round(p["offset_m"], 1)} for p in named],
    })

    g10, g10_at = gradient_stats(s, y, 10.0)
    g50, g50_at = gradient_stats(s, y, 50.0)
    stats = {
        "length_2d_m": round(float(s[-1]), 1), "length_3d_m": round(float(s3[-1]), 1),
        "start_alt_m": round(float(y[0]), 1), "finish_alt_m": round(float(y[-1]), 1),
        "drop_m": round(float(y[0] - y[-1]), 1),
        "mean_gradient_pct": round(float((y[0] - y[-1]) / s[-1] * 100), 1),
        "max_gradient_10m_pct": round(float(g10) * 100, 1), "max_gradient_10m_at_s": round(g10_at, 0),
        "max_gradient_50m_pct": round(float(g50) * 100, 1), "max_gradient_50m_at_s": round(g50_at, 0),
    }
    write_json(out / "line_stats.json", stats)
    print(f"[terrain] line stats {stats}")

    def grid_meta(g: dict, file: str) -> dict:
        rows, cols = int(round(g["size_z"] / g["res"])), int(round(g["size_x"] / g["res"]))
        return {"file": file, "format": "float32_le", "width": cols, "height": rows,
                "res_m": g["res"], "e0": g["e0"], "n0": g["n0"],
                "size_x_m": g["size_x"], "size_z_m": g["size_z"],
                # Godot world position of the grid's NW corner (x = E - E0_core, z = -(N - N0_core))
                "world_min_x": g["e0"] - core["e0"],
                "world_min_z": -(g["n0"] + g["size_z"] - core["n0"])}

    write_json(out / "meta.json", {
        "track": "Streif, Kitzbühel",
        "crs": crs,
        "mapping": "x = E - E0, y = h (m a.s.l.), z = -(N - N0); E0/N0 = core SW corner; "
                   "pixel (col,row) is a cell centre, row 0 = north",
        "origin_e0": core["e0"], "origin_n0": core["n0"], "origin_height": 0.0,
        "core": grid_meta(core, "height.r32"),
        "far": grid_meta(far, "far_height.r32"),
        "snow_depth_m": config.SNOW_DEPTH_M,
        "generated": dt.date.today().isoformat(),
        "sources": [
            "Datenquelle: Land Tirol - data.tirol.gv.at (DGM/DOM 50 cm, CC BY 4.0)",
            "© OpenStreetMap contributors (ODbL 1.0)",
        ],
    })
    print("[terrain] done")


if __name__ == "__main__":
    main()
