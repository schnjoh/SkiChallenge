"""Terrain3D control map, a debug splat and a winterised colour map.

Outputs:
  game/data/streif/control.r32   uint32 LE Terrain3D control map (core grid):
                                 base id << 27 | overlay id << 22 | blend(0-255) << 14, autoshader off
  game/data/streif/colormap.jpg  orthophoto converted to a winter look (RGB tint)
  data/raw/derived/splat.png     RGBA weights (snow, piste, forest, rock) for previews only
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage

import config
import winter
from common import read_json
from geo import grid_shape

DERIVED = config.RAW / "derived"


def encode_control(w: np.ndarray) -> np.ndarray:
    """Weights (4, H, W) -> Terrain3D control bits: two strongest layers + blend."""
    order = np.argsort(-w, axis=0)
    base = order[0].astype(np.uint32)
    over = order[1].astype(np.uint32)
    wb = np.take_along_axis(w, order[0:1], 0)[0]
    wo = np.take_along_axis(w, order[1:2], 0)[0]
    blend = np.round(255.0 * wo / np.maximum(wb + wo, 1e-6)).astype(np.uint32)
    return (base << 27) | (over << 22) | (blend << 14)


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    res = core["res"]
    height = np.fromfile(config.OUT / "height.r32", dtype="<f4").reshape(grid_shape(core))
    rgb = np.load(DERIVED / "ortho_core_1m.npy").astype(np.float32)

    dgm05 = np.load(DERIVED / "dgm_core_05.npy")
    dom05 = np.load(DERIVED / "dom_core_05.npy")
    chm = (dom05 - dgm05).reshape(dgm05.shape[0] // 2, 2, dgm05.shape[1] // 2, 2).max(axis=(1, 3))
    bmask = np.load(DERIVED / "building_mask_05.npy")
    bmask = bmask.reshape(bmask.shape[0] // 2, 2, bmask.shape[1] // 2, 2).any(axis=(1, 3))
    chm = np.where(bmask, 0.0, chm)
    corridor = np.load(DERIVED / "corridor_dist.npy")

    forest = ndimage.gaussian_filter((chm > config.TREE_MIN_HEIGHT_M).astype(np.float32), 1.5)
    rock = winter.rock_weight(height, res) * (1 - forest)
    piste = np.clip((2.0 - corridor) / 6.0, 0.0, 1.0)  # soft 6 m edge outside the corridor
    rock *= 1 - piste
    forest *= 1 - piste
    snow = np.clip(1.0 - piste - forest - rock, 0.0, 1.0)
    w = np.zeros((4,) + snow.shape, np.float32)
    w[config.TEX_SNOW], w[config.TEX_PISTE], w[config.TEX_FOREST], w[config.TEX_ROCK] = snow, piste, forest, rock
    w /= np.maximum(w.sum(0), 1e-6)

    encode_control(w).astype("<u4").tofile(config.OUT / "control.r32")
    splat = (w.transpose(1, 2, 0) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(splat, "RGBA").save(DERIVED / "splat.png")

    col = winter.colour(rgb, np.clip(forest, 0, 1), tree_canopy=False)
    Image.fromarray(col, "RGB").save(config.OUT / "colormap.jpg", quality=88)
    share = w.reshape(4, -1).mean(1)
    print(f"[splat] snow {share[0]:.2f} piste {share[1]:.2f} forest {share[2]:.2f} rock {share[3]:.2f}")


if __name__ == "__main__":
    main()
