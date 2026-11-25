"""Build the game heightmaps, race line and section table.

Inputs:  data/raw/terrain/* (manifest data/raw/derived/tiles.json), line_31255.json, extent.json
Outputs (game/data/streif/):
  height.r32      core snow-surface heights, float32 LE, row 0 = north; samples are vertices
  far_height.r32  4 m far ring (DGM), same conventions
  meta.json       grid definitions + world mapping + provenance
  line.json       race line in Godot coordinates (x, y, z, s)
  sections.json   named sections with s, width
  line_stats.json measured length / drop / gradients
Intermediate (data/raw/derived/): dgm_core_05.npy, dom_core_05.npy (0.5 m, anchor 1 m),
  corridor_dist.npy (1 m, distance to corridor edge, includes the finish run-out)
"""
from __future__ import annotations

import datetime as dt

import numpy as np
from rasterio.warp import Resampling
from scipy import ndimage

import config
from common import read_json, write_json
from geo import (distance_to_polyline, grid_meta, fill_nodata, mosaic_to_grid, nearest_line_index,
                 resample_polyline, sample_bilinear, smooth_polyline, write_r32)

DERIVED = config.RAW / "derived"
TERRAIN = config.RAW / "terrain"


def tile_paths(kind: str) -> list:
    files = read_json(DERIVED / "tiles.json")[kind]
    return [TERRAIN / f for f in files]


def _arc(pts: np.ndarray) -> np.ndarray:
    return np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])


def _finish_index(s: np.ndarray, h: np.ndarray) -> int | None:
    below = np.where((h <= config.FINISH_ALTITUDE_M) & (s > s[-1] * 0.66))[0]
    return int(below[0]) if len(below) else None


def build_line(dgm: np.ndarray, core: dict) -> tuple[np.ndarray, np.ndarray, list[dict]]:
    """Race line (E, N) up to the finish, plus the run-out continuation for the corridor.

    The finish is located on the raw line first; smoothing then runs on the line incl. a
    run-out, so the valley segments beyond the finish cannot bend the last metres.
    """
    src = read_json(DERIVED / "line_31255.json")
    raw = resample_polyline(np.asarray(src["points"], float), config.LINE_SPACING_M)
    s_raw = _arc(raw)
    k = _finish_index(s_raw, sample_bilinear(dgm, core, raw[:, 0], raw[:, 1]))
    if k is None:
        print(f"[terrain] WARNING: line never drops below {config.FINISH_ALTITUDE_M} m – no finish cut")
        k = len(raw) - 1
    k_ext = min(len(raw) - 1, k + int(config.FINISH_RUNOUT_M / config.LINE_SPACING_M))
    ext = smooth_polyline(raw[: k_ext + 1], config.LINE_SMOOTH_SIGMA_M / config.LINE_SPACING_M)
    ext = resample_polyline(ext, config.LINE_SPACING_M)
    s_ext = _arc(ext)
    k2 = _finish_index(s_ext, sample_bilinear(dgm, core, ext[:, 0], ext[:, 1]))
    line = ext[: (k2 if k2 is not None else len(ext) - 1) + 1]
    s = _arc(line)
    named = []
    for p in src["named"]:
        d = np.hypot(line[:, 0] - p["e"], line[:, 1] - p["n"])
        i = int(np.argmin(d))
        named.append({"name": p["name"], "s": float(s[i]), "index": i, "offset_m": float(d[i])})
    named.sort(key=lambda x: x["s"])
    return line, ext, named


def per_point(named: list[dict], n_pts: int, values: dict[str, float], default: float) -> np.ndarray:
    """Step function along the line (value of the last passed named point), smoothed over ~40 m."""
    w = np.full(n_pts, values.get("Start", default), dtype=float)
    for p in named:
        w[p["index"]:] = values.get(p["name"], default)
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
            best, at = float(g), float(s[i])
    return best, at


def main() -> None:
    ext_def = read_json(DERIVED / "extent.json")
    core, far = ext_def["core"], ext_def["far"]
    crs = config.CRS_PROJECT
    core05 = dict(core, res=0.5, anchor=core["res"])

    print("[terrain] mosaicking 0.5 m DGM/DOM")
    dgm05 = fill_nodata(mosaic_to_grid(tile_paths("dgm"), core05, crs, Resampling.nearest))
    dom05 = fill_nodata(mosaic_to_grid(tile_paths("dom"), core05, crs, Resampling.nearest))
    dom05 = np.maximum(dom05, dgm05)
    np.save(DERIVED / "dgm_core_05.npy", dgm05.astype(np.float32))
    np.save(DERIVED / "dom_core_05.npy", dom05.astype(np.float32))
    # 1 m vertex = mean of its 2x2 half-metre samples (exact by grid construction)
    dgm = dgm05.reshape(dgm05.shape[0] // 2, 2, dgm05.shape[1] // 2, 2).mean(axis=(1, 3))

    line, ext, named = build_line(dgm, core)
    n_ext = len(ext)
    widths = per_point(named + [{"name": "_", "index": len(line), "s": 0}], n_ext,
                       config.SECTION_WIDTHS_M | {"_": config.SECTION_WIDTHS_M["Zielsprung"]},
                       config.PISTE_DEFAULT_WIDTH_M)
    road = per_point(named, n_ext, {n: 1.0 for n in config.ROAD_SECTIONS}, 0.0)
    dist = distance_to_polyline(core, ext)
    near = nearest_line_index(core, ext)
    half_w = widths[near] / 2.0
    np.save(DERIVED / "corridor_dist.npy", (dist - half_w).astype(np.float32))

    # Snow surface: smooth the summer micro relief inside the corridor (soft 10 m edge);
    # forest-road sections get a much stronger smoothing to round road cuts into a plane.
    smooth = ndimage.gaussian_filter(dgm, config.SNOW_SMOOTH_SIGMA_M / core["res"])
    smooth_road = ndimage.gaussian_filter(dgm, config.ROAD_SMOOTH_SIGMA_M / core["res"])
    road_w = road[near]
    target = smooth * (1.0 - road_w) + smooth_road * road_w
    wgt = np.clip((half_w + 10.0 - dist) / 10.0, 0.0, 1.0)
    height = (dgm * (1.0 - wgt) + target * wgt + config.SNOW_DEPTH_M).astype(np.float32)

    out = config.OUT
    write_r32(out / "height.r32", height)
    print(f"[terrain] height.r32 {height.shape} {height.min():.1f}..{height.max():.1f} m")

    # Race line in Godot coordinates on the snow surface.
    y = sample_bilinear(height, core, line[:, 0], line[:, 1])
    x = line[:, 0] - core["e0"]
    z = -(line[:, 1] - core["n0"])
    s = _arc(line)
    s3 = np.concatenate([[0.0], np.cumsum(np.sqrt(np.diff(x) ** 2 + np.diff(z) ** 2 + np.diff(y) ** 2))])
    write_json(out / "line.json", {
        "source": f"OpenStreetMap relation {config.OSM_RELATION_ID} (ODbL), smoothed",
        "spacing_m": config.LINE_SPACING_M,
        "fields": ["x", "y", "z", "s"],
        "points": [[round(float(a), 3), round(float(b), 3), round(float(c), 3), round(float(d), 2)]
                   for a, b, c, d in zip(x, y, z, s)],
    })
    write_json(out / "sections.json", {
        "note": "Editable. s = horizontal distance from start along line.json (m).",
        "sections": [{"name": "Start", "s": 0.0, "width_m": config.SECTION_WIDTHS_M["Start"],
                      "osm_offset_m": 0.0}]
        + [{"name": p["name"], "s": round(p["s"], 1),
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
        "max_gradient_10m_pct": round(g10 * 100, 1), "max_gradient_10m_at_s": round(g10_at, 0),
        "max_gradient_50m_pct": round(g50 * 100, 1), "max_gradient_50m_at_s": round(g50_at, 0),
    }
    write_json(out / "line_stats.json", stats)
    print(f"[terrain] line stats {stats}")

    write_json(out / "meta.json", {
        "track": "Streif, Kitzbühel",
        "crs": crs,
        "mapping": "x = E - E0, y = h (m a.s.l.), z = -(N - N0). Samples are vertices: "
                   "sample (col,row) of a grid lies at (world_min_x + col*res, world_min_z + row*res); "
                   "row 0 = north. Same as Terrain3D import_images at (world_min_x, 0, world_min_z).",
        "origin_e0": core["e0"], "origin_n0": core["n0"], "origin_height": 0.0,
        "core": grid_meta(core, core, "height.r32"),
        "far": grid_meta(far, core, "far_height.r32") | {"color": "far_color.jpg", "valid": "far_valid.png"},
        "horizon": grid_meta(ext_def["horizon"], core, "horizon_height.r32")
        | {"color": "horizon_color.jpg", "valid": "horizon_valid.png"},
        "control": {"file": "control.r32", "format": "uint32_le Terrain3D control map, same grid as core"},
        "colormap": {"file": "colormap.jpg", "note": "RGB tint, same grid as core"},
        "snow_depth_m": config.SNOW_DEPTH_M,
        "textures": {"snow": config.TEX_SNOW, "piste": config.TEX_PISTE,
                     "forest": config.TEX_FOREST, "rock": config.TEX_ROCK},
        "generated": dt.date.today().isoformat(),
        "sources": [
            "Datenquelle: Land Tirol - data.tirol.gv.at (DGM/DOM 50 cm, CC BY 4.0)",
            "© OpenStreetMap contributors (ODbL 1.0)",
        ],
    })
    print("[terrain] done")


if __name__ == "__main__":
    main()
