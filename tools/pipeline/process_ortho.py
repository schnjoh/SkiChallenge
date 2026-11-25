"""Reproject the orthophoto (EPSG:31254, 0.5 m) onto the 1 m core grid (EPSG:31255).

Output (intermediate): data/raw/derived/ortho_core_1m.npy  uint8 (3, rows, cols)
"""
from __future__ import annotations

import numpy as np
from rasterio.warp import Resampling

import config
from common import read_json
from geo import mosaic_to_grid

DERIVED = config.RAW / "derived"


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    g = dict(core, res=config.SPLAT_RES_M)
    paths = sorted((config.RAW / "ortho").glob("ortho_*.tif"))
    rgb = mosaic_to_grid(paths, g, config.CRS_PROJECT, Resampling.average, bands=3,
                         dtype="uint8", nodata=0)
    np.save(DERIVED / "ortho_core_1m.npy", rgb)
    print(f"[ortho] {rgb.shape}, mean RGB {rgb.reshape(3, -1).mean(1).round(1)}")


if __name__ == "__main__":
    main()
