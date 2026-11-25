"""Minimal WCS 1.0.0 GetCoverage client (Land Tirol ArcGIS services)."""
from __future__ import annotations

from pathlib import Path

import rasterio

from common import http_get


def get_coverage(base: str, coverage: str, crs: str, bbox: tuple[float, float, float, float],
                 res: float, out: Path, expect_bands: int | None = None) -> Path:
    """Download one GeoTIFF tile unless a valid cached copy exists."""
    if out.exists() and _valid(out, crs, expect_bands):
        return out
    params = {
        "service": "WCS", "version": "1.0.0", "request": "GetCoverage", "coverage": coverage,
        "crs": crs, "bbox": ",".join(f"{v:.3f}" for v in bbox), "resx": res, "resy": res,
        "format": "GeoTIFF",
    }
    data = http_get(base, params=params, timeout=600)
    if not data.startswith((b"II*\x00", b"MM\x00*")):
        raise RuntimeError(f"WCS returned no TIFF for {coverage} {bbox}: {data[:300]!r}")
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".part")
    tmp.write_bytes(data)
    if not _valid(tmp, crs, expect_bands):
        raise RuntimeError(f"invalid GeoTIFF from WCS: {tmp}")
    tmp.replace(out)
    return out


def _valid(path: Path, crs: str, expect_bands: int | None) -> bool:
    try:
        with rasterio.open(path) as ds:
            ok = ds.width > 0 and ds.height > 0
            if ds.crs is not None and ds.crs.to_epsg() is not None:
                ok = ok and f"EPSG:{ds.crs.to_epsg()}" == crs
            if expect_bands is not None:
                ok = ok and ds.count >= expect_bands
            return ok
    except Exception:
        return False


def tiles(e0: float, n0: float, size_x: float, size_z: float, tile: float,
          shift: float = 0.0) -> list[tuple[int, int, tuple[float, float, float, float]]]:
    """Split an extent into tiles; ``shift`` offsets the bbox (pixel-centre alignment)."""
    out = []
    nx, nz = int(-(-size_x // tile)), int(-(-size_z // tile))
    for j in range(nz):
        for i in range(nx):
            x0 = e0 + i * tile + shift
            y0 = n0 + j * tile + shift
            x1 = min(e0 + size_x, e0 + (i + 1) * tile) + shift
            y1 = min(n0 + size_z, n0 + (j + 1) * tile) + shift
            out.append((i, j, (x0, y0, x1, y1)))
    return out
