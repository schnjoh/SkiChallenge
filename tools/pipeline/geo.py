"""Grid / raster helpers shared by the processing steps.

Grid convention (DESIGN.md 4.1, binding; identical to Terrain3D's import):
    world x = E - E0,  y = h,  z = -(N - N0)          (E0/N0 = core origin, meta.json)
A grid dict has e0, n0, size_x, size_z, res and ``anchor`` (default = res). Its samples are
*vertices*; sample (col, row), row 0 = north, lies at
    E = e0 + (col + 0.5) * res - anchor / 2,   N = n0 + size_z - (row + 0.5) * res + anchor / 2
For the 1 m core (anchor 1): E = E0 + col, N = N0 + 3072 - row  ->  x = col, z = row - 3072.
A 0.5 m grid with anchor 1 subdivides each 1 m vertex cell into exactly 2x2 samples.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import rasterio
from affine import Affine
from rasterio.merge import merge
from rasterio.warp import Resampling, reproject
from scipy import ndimage


def _anchor(g: dict) -> float:
    return float(g.get("anchor", g["res"]))


def grid_area(g: dict) -> tuple[float, float, float, float]:
    """Pixel-area bounds (left, bottom, right, top) of grid ``g``."""
    a = _anchor(g)
    left = g["e0"] - a / 2
    top = g["n0"] + g["size_z"] + a / 2
    rows, cols = grid_shape(g)
    return left, top - rows * g["res"], left + cols * g["res"], top


def grid_transform(g: dict) -> Affine:
    left, _, _, top = grid_area(g)
    return Affine(g["res"], 0.0, left, 0.0, -g["res"], top)


def grid_shape(g: dict) -> tuple[int, int]:
    return int(round(g["size_z"] / g["res"])), int(round(g["size_x"] / g["res"]))


def pixel_to_world(g: dict, core: dict, col: np.ndarray, row: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Godot (x, z) of sample (col, row) of grid ``g``; ``core`` defines E0/N0."""
    left, _, _, top = grid_area(g)
    e = left + (np.asarray(col, float) + 0.5) * g["res"]
    n = top - (np.asarray(row, float) + 0.5) * g["res"]
    return e - core["e0"], -(n - core["n0"])


def mosaic_to_grid(paths: list[Path], g: dict, crs: str, resampling: Resampling,
                   bands: int = 1, dtype: str = "float32", nodata: float | None = -9999.0) -> np.ndarray:
    """Mosaic GeoTIFF tiles and resample them onto grid ``g`` (EPSG of ``crs``)."""
    srcs = [rasterio.open(p) for p in paths]
    try:
        src_nodata = srcs[0].nodata if srcs[0].nodata is not None else nodata
        arr, tr = merge(srcs, nodata=src_nodata)
        src_crs = srcs[0].crs or crs
    finally:
        for s in srcs:
            s.close()
    rows, cols = grid_shape(g)
    out = np.full((bands, rows, cols), np.nan if dtype.startswith("float") else 0, dtype=dtype)
    for b in range(bands):
        reproject(
            source=arr[b].astype(dtype), destination=out[b], src_transform=tr, src_crs=src_crs,
            src_nodata=src_nodata, dst_transform=grid_transform(g), dst_crs=crs,
            dst_nodata=np.nan if dtype.startswith("float") else 0, resampling=resampling,
        )
    return out if bands > 1 else out[0]


def fill_nodata(a: np.ndarray) -> np.ndarray:
    """Fill NaNs with the nearest valid value."""
    mask = ~np.isfinite(a)
    if not mask.any():
        return a
    idx = ndimage.distance_transform_edt(mask, return_distances=False, return_indices=True)
    return a[tuple(idx)]


def world_to_pixel(g: dict, e: np.ndarray, n: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Fractional sample coordinates (col, row) of projected points (E, N)."""
    left, _, _, top = grid_area(g)
    return (e - left) / g["res"] - 0.5, (top - n) / g["res"] - 0.5


def sample_bilinear(a: np.ndarray, g: dict, e: np.ndarray, n: np.ndarray) -> np.ndarray:
    col, row = world_to_pixel(g, np.asarray(e, float), np.asarray(n, float))
    return ndimage.map_coordinates(a, [row, col], order=1, mode="nearest")


def distance_to_polyline(g: dict, line_en: np.ndarray) -> np.ndarray:
    """Distance (m) of every grid cell centre to the polyline (rasterised, EDT based)."""
    rows, cols = grid_shape(g)
    mask = np.zeros((rows, cols), dtype=bool)
    # densify the polyline to < half a cell and burn it in
    dense = densify(line_en, g["res"] * 0.5)
    col, row = world_to_pixel(g, dense[:, 0], dense[:, 1])
    ci = np.clip(np.round(col).astype(int), 0, cols - 1)
    ri = np.clip(np.round(row).astype(int), 0, rows - 1)
    mask[ri, ci] = True
    return ndimage.distance_transform_edt(~mask) * g["res"]


def nearest_line_index(g: dict, line_en: np.ndarray) -> np.ndarray:
    """Index of the nearest (densified) line vertex per cell – used for per-section widths."""
    rows, cols = grid_shape(g)
    lab = np.zeros((rows, cols), dtype=np.int32)
    col, row = world_to_pixel(g, line_en[:, 0], line_en[:, 1])
    ci = np.clip(np.round(col).astype(int), 0, cols - 1)
    ri = np.clip(np.round(row).astype(int), 0, rows - 1)
    lab[ri, ci] = np.arange(1, len(line_en) + 1)
    _, idx = ndimage.distance_transform_edt(lab == 0, return_indices=True)
    return lab[idx[0], idx[1]] - 1


def densify(pts: np.ndarray, step: float) -> np.ndarray:
    out = [pts[0]]
    for a, b in zip(pts[:-1], pts[1:]):
        d = float(np.hypot(*(b - a)))
        k = max(1, int(np.ceil(d / step)))
        for t in np.linspace(0, 1, k + 1)[1:]:
            out.append(a + (b - a) * t)
    return np.asarray(out)


def resample_polyline(pts: np.ndarray, spacing: float) -> np.ndarray:
    seg = np.hypot(*np.diff(pts, axis=0).T)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    t = np.arange(0.0, s[-1], spacing)
    t = np.append(t, s[-1]) if s[-1] - t[-1] > 1e-6 else t
    return np.column_stack([np.interp(t, s, pts[:, 0]), np.interp(t, s, pts[:, 1])])


def smooth_polyline(pts: np.ndarray, sigma_pts: float) -> np.ndarray:
    """Gaussian smoothing along the line, endpoints pinned."""
    out = np.column_stack([ndimage.gaussian_filter1d(pts[:, i], sigma_pts, mode="nearest")
                           for i in range(2)])
    out[0], out[-1] = pts[0], pts[-1]
    return out


def write_r32(path: Path, a: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    np.ascontiguousarray(a, dtype="<f4").tofile(path)


def grid_meta(g: dict, core: dict, file: str) -> dict:
    """meta.json entry: vertex (c, r) of grid g lies at (world_min_x + c*res, world_min_z + r*res)."""
    rows, cols = grid_shape(g)
    left, _, _, top = grid_area(g)
    e = left + 0.5 * g["res"]
    n = top - 0.5 * g["res"]
    return {"file": file, "format": "float32_le", "width": cols, "height": rows, "res_m": g["res"],
            "world_min_x": e - core["e0"], "world_min_z": -(n - core["n0"])}
