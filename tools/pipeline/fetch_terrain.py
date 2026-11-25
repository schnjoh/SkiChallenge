"""Download DGM + DOM 50 cm (core) and the 5 m far ring via Land Tirol WCS (CC BY 4.0)."""
from __future__ import annotations

import config
from common import read_json
from wcs import get_coverage, tiles

DERIVED = config.RAW / "derived"
TERRAIN = config.RAW / "terrain"
NATIVE_RES = 0.5


def main() -> None:
    ext = read_json(DERIVED / "extent.json")
    core, far = ext["core"], ext["far"]
    # Native pixel centres lie on whole 0.5 m; shift the bbox by half a pixel so the
    # server returns native samples instead of resampling.
    core_tiles = tiles(core["e0"], core["n0"], core["size_x"], core["size_z"],
                       float(config.TERRAIN3D_REGION_M), shift=-NATIVE_RES / 2)
    for kind, cov in (("dgm", config.COV_DGM), ("dom", config.COV_DOM)):
        for i, j, bbox in core_tiles:
            out = TERRAIN / f"{kind}_core_{i}_{j}.tif"
            print(f"[terrain] {kind} tile {i},{j} {bbox}")
            get_coverage(config.WCS_TERRAIN, cov, config.CRS_PROJECT, bbox, NATIVE_RES, out, 1)
    for i, j, bbox in tiles(far["e0"], far["n0"], far["size_x"], far["size_z"], 4000.0):
        out = TERRAIN / f"dgm_far_{i}_{j}.tif"
        print(f"[terrain] far tile {i},{j} {bbox}")
        get_coverage(config.WCS_TERRAIN, config.COV_DGM, config.CRS_PROJECT, bbox,
                     config.FAR_RES_M, out, 1)
    print("[terrain] done")


if __name__ == "__main__":
    main()
