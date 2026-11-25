"""Download DGM + DOM (0.5 m core grid) and the far ring via Land Tirol WCS (CC BY 4.0).

Tiles are requested exactly on the pipeline grids (geo.py), so mosaicking is an identity
resample. The files used are listed in data/raw/derived/tiles.json (manifest).
"""
from __future__ import annotations

import config
from common import read_json, write_json
from geo import grid_area
from wcs import get_coverage, tile_name, tiles

DERIVED = config.RAW / "derived"
TERRAIN = config.RAW / "terrain"


def main() -> None:
    ext = read_json(DERIVED / "extent.json")
    core05 = dict(ext["core"], res=0.5, anchor=ext["core"]["res"])
    manifest = read_json(DERIVED / "tiles.json") if (DERIVED / "tiles.json").exists() else {}
    for kind, cov in (("dgm", config.COV_DGM), ("dom", config.COV_DOM)):
        files = []
        for i, j, bbox in tiles(grid_area(core05), float(config.TERRAIN3D_REGION_M)):
            out = TERRAIN / tile_name(f"{kind}05", bbox, 0.5)
            print(f"[terrain] {kind} tile {i},{j}")
            get_coverage(config.WCS_TERRAIN, cov, config.CRS_PROJECT, bbox, 0.5, out)
            files.append(out.name)
        manifest[kind] = files
    # rings: DGM + DOM (DOM - DGM gives forest for the ring colour maps)
    for ring, tile in (("far", 4608.0), ("horizon", 7424.0)):
        g = ext[ring]
        for kind, cov in (("dgm", config.COV_DGM), ("dom", config.COV_DOM)):
            files = []
            for i, j, bbox in tiles(grid_area(g), tile):
                out = TERRAIN / tile_name(f"{kind}{ring}", bbox, g["res"])
                print(f"[terrain] {ring} {kind} tile {i},{j}")
                get_coverage(config.WCS_TERRAIN, cov, config.CRS_PROJECT, bbox, g["res"], out)
                files.append(out.name)
            manifest[f"{ring}_{kind}" if kind == "dom" else ring] = files
    write_json(DERIVED / "tiles.json", manifest)
    print("[terrain] done")


if __name__ == "__main__":
    main()
