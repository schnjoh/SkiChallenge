"""Download Land Tirol orthophoto (EPSG:31254, CC BY 4.0) covering the core extent."""
from __future__ import annotations

import config
from common import read_json, transformer
from wcs import get_coverage, tiles

DERIVED = config.RAW / "derived"
ORTHO = config.RAW / "ortho"


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    t = transformer(config.CRS_PROJECT, config.CRS_ORTHO)
    corners = [(core["e0"] + dx * core["size_x"], core["n0"] + dz * core["size_z"])
               for dx in (0, 1) for dz in (0, 1)]
    pts = [t.transform(e, n) for e, n in corners]
    x0 = min(p[0] for p in pts) - 20
    y0 = min(p[1] for p in pts) - 20
    x1 = max(p[0] for p in pts) + 20
    y1 = max(p[1] for p in pts) + 20
    for i, j, bbox in tiles(x0, y0, x1 - x0, y1 - y0, 1024.0):
        out = ORTHO / f"ortho_{i}_{j}.tif"
        print(f"[ortho] tile {i},{j} {bbox}")
        get_coverage(config.WCS_ORTHO, config.COV_ORTHO, config.CRS_ORTHO, bbox,
                     config.ORTHO_RES_M, out, 3)
    print("[ortho] done")


if __name__ == "__main__":
    main()
