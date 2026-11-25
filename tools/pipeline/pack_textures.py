"""Pack CC0 PBR maps (data/raw/assets/manifest.json) into Terrain3D texture pairs.

Output (game/assets/textures/):
  <slot>_albedo_height.png  RGB = albedo, A = height
  <slot>_normal_rough.png   RGB = normal (OpenGL), A = roughness
plus .import files (VRAM compressed, mipmaps, normal-map detection off -> alpha preserved).
"""
from __future__ import annotations

import numpy as np
from PIL import Image

import config
from common import read_json

SIZE = 1024
# Target mean albedo luminance per slot: CC0 sets differ a lot in base brightness; normalising
# keeps snow white and lets the colour map carry the large-scale variation.
TARGET_LUMA = {"snow": 0.86, "piste": 0.82, "forest": 0.78, "rock": 0.5}
OUT = config.ROOT / "game" / "assets" / "textures"
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/normal_map=2
compress/channel_pack=0
mipmaps/generate=true
roughness/mode=0
process/fix_alpha_border=false
detect_3d/compress_to=0
"""


def _load(path: str, mode: str) -> np.ndarray:
    img = Image.open(config.ROOT / path)
    if img.mode in ("I;16", "I;16B", "I"):  # 16-bit height
        a = np.asarray(img, dtype=np.float32)
        a = (a - a.min()) / max(float(a.max() - a.min()), 1.0) * 255.0
        img = Image.fromarray(a.astype(np.uint8), "L")
    return np.asarray(img.convert(mode).resize((SIZE, SIZE), Image.LANCZOS))


def main() -> None:
    if not (config.RAW / "assets" / "manifest.json").exists():
        print("[textures] no asset manifest (data/raw/assets) – keeping committed textures")
        return
    man = read_json(config.RAW / "assets" / "manifest.json")["textures"]
    OUT.mkdir(parents=True, exist_ok=True)
    for slot, info in man.items():
        f = info["files"]
        alb = _load(f["albedo"], "RGB").astype(np.float32) / 255.0
        lin = alb ** 2.2
        luma = float((lin @ np.array([0.2126, 0.7152, 0.0722])).mean()) ** (1 / 2.2)
        alb = np.clip(alb * TARGET_LUMA.get(slot, luma) / max(luma, 1e-3), 0, 1)
        alb = (alb * 255 + 0.5).astype(np.uint8)
        hgt = _load(f["height"], "L")
        nor = _load(f["normal"], "RGB")
        if info["files"].get("normal_convention", info.get("normal_convention", "gl")) == "dx":
            nor = nor.copy()
            nor[..., 1] = 255 - nor[..., 1]
        rough = _load(f["roughness"], "L")
        for name, rgb, a in (("albedo_height", alb, hgt), ("normal_rough", nor, rough)):
            out = OUT / f"{slot}_{name}.png"
            Image.fromarray(np.dstack([rgb, a]), "RGBA").save(out, optimize=True)
            out.with_suffix(".png.import").write_text(IMPORT)
        print(f"[textures] {slot} packed ({info.get('id', '?')})")


if __name__ == "__main__":
    main()
