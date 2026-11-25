"""Minimal WCS 1.0.0 GetCoverage client (Land Tirol ArcGIS services) with validated cache."""
from __future__ import annotations

from pathlib import Path

import rasterio
from pyproj import CRS

from common import http_get

Bbox = tuple[float, float, float, float]


def tile_name(prefix: str, bbox: Bbox, res: float) -> str:
    """Cache file name that encodes bbox and resolution (changed extent -> new file)."""
    return f"{prefix}_{bbox[0]:.2f}_{bbox[1]:.2f}_{bbox[2]:.2f}_{bbox[3]:.2f}_r{res:g}.tif"


def get_coverage(base: str, coverage: str, crs: str, bbox: Bbox, res: float, out: Path,
                 expect_bands: int = 1) -> Path:
    """Download one GeoTIFF tile unless a cached copy with matching CRS/bounds/res exists."""
    if out.exists() and valid(out, crs, bbox, res, expect_bands):
        return out
    params = {
        "service": "WCS", "version": "1.0.0", "request": "GetCoverage", "coverage": coverage,
        "crs": crs, "bbox": ",".join(f"{v:.3f}" for v in bbox), "resx": res, "resy": res,
        "format": "GeoTIFF",
    }
    data = http_get(base, params=params, timeout=600)
    if not data.startswith((b"II*\x00", b"MM\x00*")):  # ArcGIS returns XML errors with HTTP 200
        raise RuntimeError(f"WCS returned no TIFF for {coverage} {bbox}: {data[:300]!r}")
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".part")
    tmp.write_bytes(data)
    if not valid(tmp, crs, bbox, res, expect_bands):
        raise RuntimeError(f"WCS tile does not match the request: {tmp}")
    tmp.replace(out)
    return out


def valid(path: Path, crs: str, bbox: Bbox, res: float, expect_bands: int) -> bool:
    try:
        with rasterio.open(path) as ds:
            if ds.count < expect_bands or ds.crs is None:
                return False
            # ArcGIS WKTs carry extra datum details, so compare the identified EPSG code
            if CRS.from_wkt(ds.crs.to_wkt()).to_epsg(min_confidence=20) != CRS.from_user_input(crs).to_epsg():
                return False
            if abs(ds.res[0] - res) > 1e-6 or abs(ds.res[1] - res) > 1e-6:
                return False
            b = ds.bounds
            return all(abs(u - v) <= res / 2 for u, v in zip((b.left, b.bottom, b.right, b.top), bbox))
    except Exception:
        return False


def tiles(area: Bbox, tile: float) -> list[tuple[int, int, Bbox]]:
    """Split a pixel-area bbox (left, bottom, right, top) into tiles of at most ``tile`` m."""
    left, bottom, right, top = area
    out = []
    nx = int(-(-(right - left) // tile))
    nz = int(-(-(top - bottom) // tile))
    for j in range(nz):
        for i in range(nx):
            out.append((i, j, (left + i * tile, bottom + j * tile,
                               min(right, left + (i + 1) * tile), min(top, bottom + (j + 1) * tile))))
    return out
