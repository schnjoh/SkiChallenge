"""Shared 'winterisation' of summer orthophotos into snow-covered colour maps."""
from __future__ import annotations

import numpy as np
from scipy import ndimage

import config


def forest_weight(chm: np.ndarray, res: float) -> np.ndarray:
    """0..1 forest cover from canopy height (DOM - DGM)."""
    return np.clip(ndimage.gaussian_filter((chm > config.TREE_MIN_HEIGHT_M).astype(np.float32),
                                           1.5 / max(res, 1.0)), 0.0, 1.0)


def rock_weight(height: np.ndarray, res: float, min_slope_deg: float = 40.0) -> np.ndarray:
    """Exposed rock by slope only. An ortho grey/brightness rule was dropped: it classified
    gravel, concrete and roofs (e.g. at the start area) as rock (Phase 2 screenshot review)."""
    gy, gx = np.gradient(height, res)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    return ndimage.gaussian_filter(np.clip((slope - min_slope_deg) / 6.0, 0.0, 1.0), 1.0)


def colour(rgb: np.ndarray, forest: np.ndarray, rock: np.ndarray | None = None,
           tree_canopy: bool = False) -> np.ndarray:
    """(3,H,W) summer RGB -> (H,W,3) uint8 winter colours.

    ``tree_canopy`` False (core): trees are separate meshes, the ground under them is light snowy
    forest floor. True (rings): no tree meshes, so the canopy itself is painted dark green.
    """
    r, g, b = rgb.astype(np.float32)
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
    snow = np.array([0.95, 0.97, 1.0])[:, None, None] * (0.9 + 0.1 * lum[None])
    if tree_canopy:
        under = np.stack([0.10 + lum * 0.25, 0.16 + lum * 0.3, 0.12 + lum * 0.25])
    else:
        under = np.stack([0.72 + lum * 0.1, 0.74 + lum * 0.1, 0.74 + lum * 0.1])
    col = snow * (1 - forest[None]) + under * forest[None]
    if rock is not None:
        rock_col = np.stack([0.42 + lum * 0.3] * 3)
        col = col * (1 - rock[None]) + rock_col * rock[None]
    return (np.clip(col, 0, 1) * 255).astype(np.uint8).transpose(1, 2, 0)
