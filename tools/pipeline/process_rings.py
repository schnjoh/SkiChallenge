"""Far (4 m) and horizon (32 m) terrain rings around the core: heights, colour map, valid mask.

Outputs (game/data/streif/): {ring}_height.r32, {ring}_color.jpg, {ring}_valid.png
Areas without Land Tirol data (outside Tyrol) are marked invalid; their heights are filled by
nearest neighbour only to keep the mesh continuous, and the mesh drops those cells.
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from rasterio.warp import Resampling

import config
import winter
from common import read_json
from geo import fill_nodata, mosaic_to_grid, write_r32

DERIVED = config.RAW / "derived"
KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'


def main() -> None:
    ext = read_json(DERIVED / "extent.json")
    man = read_json(DERIVED / "tiles.json")
    crs = config.CRS_PROJECT
    for ring in ("far", "horizon"):
        g = ext[ring]
        dgm = mosaic_to_grid([config.RAW / "terrain" / f for f in man[ring]], g, crs, Resampling.nearest)
        dom = mosaic_to_grid([config.RAW / "terrain" / f for f in man[f"{ring}_dom"]], g, crs, Resampling.nearest)
        valid = np.isfinite(dgm) & (dgm > 0)
        dgm = fill_nodata(np.where(valid, dgm, np.nan))
        dom = np.where(np.isfinite(dom), dom, dgm)
        rgb = mosaic_to_grid([config.RAW / "ortho" / f for f in man[f"{ring}_ortho"]], g, crs,
                             Resampling.average, bands=3, dtype="uint8", nodata=0).astype(np.float32)
        forest = winter.forest_weight(np.maximum(dom - dgm, 0.0), g["res"])
        rock = winter.rock_weight(dgm, g["res"]) * (1 - forest)
        col = winter.colour(rgb, forest, rock, tree_canopy=True)
        out = config.OUT
        write_r32(out / f"{ring}_height.r32", dgm.astype(np.float32))
        Image.fromarray(col, "RGB").save(out / f"{ring}_color.jpg", quality=85)
        Image.fromarray((valid * 255).astype(np.uint8), "L").save(out / f"{ring}_valid.png")
        for f in (f"{ring}_color.jpg", f"{ring}_valid.png"):
            (out / f"{f}.import").write_text(KEEP_IMPORT)
        print(f"[rings] {ring}: {dgm.shape}, valid {valid.mean() * 100:.1f} %, forest {forest.mean():.2f}")


if __name__ == "__main__":
    main()
