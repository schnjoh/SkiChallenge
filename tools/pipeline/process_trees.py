"""Tree positions from vegetation height (DOM - DGM, 0.5 m).

Tree tops = local maxima of the canopy height model above TREE_MIN_HEIGHT_M, excluding
the piste corridor (+ clearance) and OSM building footprints (+1.5 m).
Output: game/data/streif/trees.bin  float32 LE triples (x, z, height) in Godot coordinates.
"""
from __future__ import annotations

import numpy as np
from scipy import ndimage

import config
from common import read_json, write_json

DERIVED = config.RAW / "derived"


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    dgm = np.load(DERIVED / "dgm_core_05.npy")
    dom = np.load(DERIVED / "dom_core_05.npy")
    chm = ndimage.gaussian_filter(dom - dgm, 0.7)  # light smoothing against double peaks
    res = 0.5
    win = int(round(config.TREE_PEAK_WINDOW_M / res)) | 1
    peaks = (chm == ndimage.maximum_filter(chm, size=win)) & (chm > config.TREE_MIN_HEIGHT_M)

    raw = dom - dgm
    building = np.load(DERIVED / "building_mask_05.npy")

    corridor = np.load(DERIVED / "corridor_dist.npy")  # 1 m grid: dist to corridor edge
    corridor05 = np.kron(corridor, np.ones((2, 2), np.float32))
    keep = peaks & ~building & (corridor05 > config.TREE_CORRIDOR_CLEARANCE_M)
    rows, cols = np.nonzero(keep)
    x = (cols + 0.5) * res
    z = -(core["size_z"] - (rows + 0.5) * res)
    hgt = raw[rows, cols]
    hgt = np.clip(hgt, config.TREE_MIN_HEIGHT_M, 45.0)
    data = np.column_stack([x, z, hgt]).astype("<f4")
    out = config.OUT / "trees.bin"
    data.tofile(out)
    write_json(config.OUT / "trees_meta.json", {
        "count": int(len(data)), "format": "float32_le (x, z, height_m)",
        "min_height_m": config.TREE_MIN_HEIGHT_M,
        "removed_buildings": int((peaks & building).sum()),
        "removed_corridor": int((peaks & ~building & (corridor05 <= config.TREE_CORRIDOR_CLEARANCE_M)).sum()),
    })
    print(f"[trees] {len(data)} trees (median height {np.median(hgt):.1f} m) -> {out}")


if __name__ == "__main__":
    main()
