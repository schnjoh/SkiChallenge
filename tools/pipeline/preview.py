"""Render pipeline preview images to docs/img/ for visual inspection."""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw

import config
from common import read_json

DOCS = config.ROOT / "docs" / "img"


def main(scale: int = 2) -> None:
    meta = read_json(config.OUT / "meta.json")
    c = meta["core"]
    h = np.fromfile(config.OUT / c["file"], "<f4").reshape(c["height"], c["width"])
    gy, gx = np.gradient(h)
    shade = np.clip(0.5 + (gx * -0.7 + gy * 0.7) * 0.6, 0, 1)
    hs = Image.fromarray((shade * 255).astype(np.uint8)).convert("RGB")
    splat = Image.open(config.OUT / "splat.png").convert("RGBA")
    sp = np.asarray(splat).astype(np.float32) / 255
    pal = np.array([[235, 240, 250], [120, 170, 255], [30, 110, 50], [130, 110, 90]], np.float32)
    col = np.einsum("hwk,kc->hwc", sp, pal)
    sp_img = Image.fromarray(np.clip(col * (0.55 + 0.45 * shade[..., None]), 0, 255).astype(np.uint8))
    trees = np.fromfile(config.OUT / "trees.bin", "<f4").reshape(-1, 3)
    line = np.asarray(read_json(config.OUT / "line.json")["points"])
    secs = read_json(config.OUT / "sections.json")["sections"]

    def overlay(img: Image.Image, with_trees: bool) -> Image.Image:
        img = img.resize((c["width"] // scale, c["height"] // scale))
        d = ImageDraw.Draw(img)
        if with_trees:
            for x, z, _ in trees[::3]:
                px, py = x / scale, (c["height"] + z) / scale
                d.point((px, py), fill=(0, 90, 0))
        pts = [(x / scale, (c["height"] + z) / scale) for x, _, z, _ in line]
        d.line(pts, fill=(220, 20, 20), width=3)
        for s in secs:
            i = int(np.argmin(np.abs(line[:, 3] - s["s"])))
            x, z = line[i, 0] / scale, (c["height"] + line[i, 2]) / scale
            d.ellipse((x - 5, z - 5, x + 5, z + 5), outline=(0, 0, 0), width=2)
            d.text((x + 8, z - 6), f"{s['name']} {s['s']:.0f}", fill=(0, 0, 0))
        return img

    overlay(hs, True).save(DOCS / "preview_hillshade_trees.png")
    overlay(sp_img, False).save(DOCS / "preview_splat.png")
    Image.open(config.OUT / "colormap.jpg").resize((c["width"] // scale, c["height"] // scale)).save(
        DOCS / "preview_colormap.jpg", quality=80)
    # elevation profile
    W, H = 1200, 400
    prof = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(prof)
    s, y = line[:, 3], line[:, 1]
    sx = lambda v: 40 + v / s[-1] * (W - 60)
    sy = lambda v: H - 30 - (v - 780) / (1700 - 780) * (H - 60)
    d.line([(sx(a), sy(b)) for a, b in zip(s, y)], fill=(200, 0, 0), width=2)
    for sec in secs:
        i = int(np.argmin(np.abs(s - sec["s"])))
        d.line([(sx(s[i]), sy(y[i]) - 5), (sx(s[i]), sy(y[i]) + 5)], fill=(0, 0, 0))
        d.text((sx(s[i]) + 2, sy(y[i]) - 18), sec["name"][:10], fill=(0, 0, 0))
    prof.save(DOCS / "preview_profile.png")
    print("[preview] written to", DOCS)


if __name__ == "__main__":
    main()
