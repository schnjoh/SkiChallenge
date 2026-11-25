"""Download Land Tirol orthophoto (EPSG:31254, CC BY 4.0) covering the core extent."""
from __future__ import annotations

import config
from common import read_json, transformer, write_json
from geo import grid_area
from wcs import get_coverage, tile_name, tiles

DERIVED = config.RAW / "derived"
ORTHO = config.RAW / "ortho"


def fetch(g: dict, r: float, tile: float, prefix: str) -> list[str]:
    """Ortho tiles (EPSG:31254) covering grid ``g`` at resolution ``r``."""
    left, bottom, right, top = grid_area(g)
    t = transformer(config.CRS_PROJECT, config.CRS_ORTHO)
    pts = [t.transform(e, n) for e in (left, right) for n in (bottom, top)]
    # snap the 31254 bbox to the ortho resolution (stable cache names)
    x0 = (min(p[0] for p in pts) - 20) // r * r
    y0 = (min(p[1] for p in pts) - 20) // r * r
    x1 = -(-(max(p[0] for p in pts) + 20) // r) * r
    y1 = -(-(max(p[1] for p in pts) + 20) // r) * r
    files = []
    for i, j, bbox in tiles((x0, y0, x1, y1), tile):
        out = ORTHO / tile_name(prefix, bbox, r)
        print(f"[ortho] {prefix} tile {i},{j}")
        get_coverage(config.WCS_ORTHO, config.COV_ORTHO, config.CRS_ORTHO, bbox, r, out, 3)
        files.append(out.name)
    return files


def main() -> None:
    ext = read_json(DERIVED / "extent.json")
    manifest = read_json(DERIVED / "tiles.json") if (DERIVED / "tiles.json").exists() else {}
    manifest["ortho"] = fetch(ext["core"], config.ORTHO_RES_M, 1024.0, "ortho")
    manifest["far_ortho"] = fetch(ext["far"], ext["far"]["res"], 4800.0, "orthofar")
    manifest["horizon_ortho"] = fetch(ext["horizon"], ext["horizon"]["res"], 16000.0, "orthohorizon")
    write_json(DERIVED / "tiles.json", manifest)
    print("[ortho] done")


if __name__ == "__main__":
    main()
