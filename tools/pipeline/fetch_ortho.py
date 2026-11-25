"""Download Land Tirol orthophoto (EPSG:31254, CC BY 4.0) covering the core extent."""
from __future__ import annotations

import config
from common import read_json, transformer, write_json
from geo import grid_area
from wcs import get_coverage, tile_name, tiles

DERIVED = config.RAW / "derived"
ORTHO = config.RAW / "ortho"


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    left, bottom, right, top = grid_area(core)
    t = transformer(config.CRS_PROJECT, config.CRS_ORTHO)
    pts = [t.transform(e, n) for e in (left, right) for n in (bottom, top)]
    r = config.ORTHO_RES_M
    # snap the 31254 bbox to the ortho resolution (stable cache names)
    x0 = (min(p[0] for p in pts) - 20) // r * r
    y0 = (min(p[1] for p in pts) - 20) // r * r
    x1 = -(-(max(p[0] for p in pts) + 20) // r) * r
    y1 = -(-(max(p[1] for p in pts) + 20) // r) * r
    files = []
    for i, j, bbox in tiles((x0, y0, x1, y1), 1024.0):
        out = ORTHO / tile_name("ortho", bbox, r)
        print(f"[ortho] tile {i},{j}")
        get_coverage(config.WCS_ORTHO, config.COV_ORTHO, config.CRS_ORTHO, bbox, r, out, 3)
        files.append(out.name)
    manifest = read_json(DERIVED / "tiles.json") if (DERIVED / "tiles.json").exists() else {}
    manifest["ortho"] = files
    write_json(DERIVED / "tiles.json", manifest)
    print("[ortho] done")


if __name__ == "__main__":
    main()
