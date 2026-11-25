"""Splat/control map and a winterised colour map from orthophoto + terrain.

Outputs (game/data/streif/):
  splat.png      RGBA weights, 1 m: R = snow, G = piste, B = forest floor, A = rock
  colormap.jpg   orthophoto converted to a winter look (tints the terrain shader)
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage

import config
from common import read_json

DERIVED = config.RAW / "derived"


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    res = config.SPLAT_RES_M
    height = np.fromfile(config.OUT / "height.r32", dtype="<f4").reshape(
        int(core["size_z"] / res), int(core["size_x"] / res))
    gy, gx = np.gradient(height, res)
    slope_deg = np.degrees(np.arctan(np.hypot(gx, gy)))

    rgb = np.load(DERIVED / "ortho_core_1m.npy").astype(np.float32)
    r, g, b = rgb
    bright = rgb.mean(0)
    sat = rgb.max(0) - rgb.min(0)
    exg = 2 * g - r - b

    dgm05 = np.load(DERIVED / "dgm_core_05.npy")
    dom05 = np.load(DERIVED / "dom_core_05.npy")
    chm = (dom05 - dgm05).reshape(dgm05.shape[0] // 2, 2, dgm05.shape[1] // 2, 2).max(axis=(1, 3))
    corridor = np.load(DERIVED / "corridor_dist.npy")
    bmask = np.load(DERIVED / "building_mask_05.npy")
    bmask = bmask.reshape(bmask.shape[0] // 2, 2, bmask.shape[1] // 2, 2).any(axis=(1, 3))
    chm = np.where(bmask, 0.0, chm)

    forest = ndimage.gaussian_filter((chm > config.TREE_MIN_HEIGHT_M).astype(np.float32), 1.5)
    rock = ((slope_deg > 38) | ((sat < 25) & (bright > 90) & (exg < 5) & (slope_deg > 28)))
    rock = ndimage.gaussian_filter(rock.astype(np.float32), 1.0) * (1 - forest)
    piste = np.clip((2.0 - corridor) / 6.0, 0.0, 1.0)  # soft 6 m edge outside the corridor
    rock *= 1 - piste
    forest *= 1 - piste
    snow = np.clip(1.0 - piste - forest - rock, 0.0, 1.0)
    w = np.stack([snow, piste, forest, rock])
    w /= np.maximum(w.sum(0), 1e-6)
    splat = (w.transpose(1, 2, 0) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(splat, "RGBA").save(config.OUT / "splat.png", optimize=True)

    # Winter colour map: desaturate, lift towards snow white except under forest.
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
    snow_col = np.array([0.93, 0.95, 1.0])[:, None, None]
    tree_col = np.stack([lum * 0.55, lum * 0.65, lum * 0.6])
    mix = np.clip(forest, 0, 1)[None]
    col = snow_col * (0.85 + 0.15 * lum[None]) * (1 - mix) + tree_col * mix
    col = (np.clip(col, 0, 1) * 255).astype(np.uint8).transpose(1, 2, 0)
    Image.fromarray(col, "RGB").save(config.OUT / "colormap.jpg", quality=88)
    share = w.reshape(4, -1).mean(1)
    print(f"[splat] snow {share[0]:.2f} piste {share[1]:.2f} forest {share[2]:.2f} rock {share[3]:.2f}")


if __name__ == "__main__":
    main()
