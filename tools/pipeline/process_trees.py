"""Tree positions from vegetation height (DOM - DGM, 0.5 m grid).

Tree tops = local maxima of the canopy height model above TREE_MIN_HEIGHT_M, excluding the
piste corridor (+ clearance) and OSM building footprints (+1.5 m).
Output: game/data/streif/trees.bin  float32 LE triples (x, z, height) in Godot coordinates.
"""
from __future__ import annotations

import numpy as np
from scipy import ndimage

import config
from common import read_json, write_json
from geo import pixel_to_world

DERIVED = config.RAW / "derived"


def up2(a: np.ndarray) -> np.ndarray:
    """1 m vertex grid -> 0.5 m grid (anchor 1 m): each vertex covers its 2x2 half-metre samples."""
    return np.kron(a, np.ones((2, 2), a.dtype))


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    core05 = dict(core, res=0.5, anchor=core["res"])
    dgm = np.load(DERIVED / "dgm_core_05.npy")
    dom = np.load(DERIVED / "dom_core_05.npy")
    raw = dom - dgm
    chm = ndimage.gaussian_filter(raw, 0.7)  # light smoothing against double peaks
    win = int(round(config.TREE_PEAK_WINDOW_M / 0.5)) | 1
    peaks = (chm == ndimage.maximum_filter(chm, size=win)) & (chm > config.TREE_MIN_HEIGHT_M)
    building = np.load(DERIVED / "building_mask_05.npy")
    corridor05 = up2(np.load(DERIVED / "corridor_dist.npy"))
    keep = peaks & ~building & (corridor05 > config.TREE_CORRIDOR_CLEARANCE_M)
    rows, cols = np.nonzero(keep)
    x, z = pixel_to_world(core05, core, cols, rows)
    inside = (x >= 0) & (x <= core["size_x"] - 1) & (z >= -core["size_z"]) & (z <= -1)
    x, z, rows, cols = x[inside], z[inside], rows[inside], cols[inside]
    hgt = np.clip(raw[rows, cols], config.TREE_MIN_HEIGHT_M, 45.0)
    data = np.column_stack([x, z, hgt]).astype("<f4")
    data.tofile(config.OUT / "trees.bin")
    write_json(config.OUT / "trees_meta.json", {
        "count": int(len(data)), "format": "float32_le (x, z, height_m)",
        "min_height_m": config.TREE_MIN_HEIGHT_M,
        "removed_buildings": int((peaks & building).sum()),
        "removed_corridor": int((peaks & ~building & (corridor05 <= config.TREE_CORRIDOR_CLEARANCE_M)).sum()),
    })
    print(f"[trees] {len(data)} trees (median height {np.median(hgt):.1f} m)")


if __name__ == "__main__":
    main()
