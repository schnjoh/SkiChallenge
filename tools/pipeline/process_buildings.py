"""Rasterise OSM building footprints (masks for trees/splat) and export buildings.json.

Outputs:
  data/raw/derived/building_mask_05.npy  bool, 0.5 m core grid (footprint dilated by 1.5 m)
  game/data/streif/buildings.json        footprints in Godot coords + roof height from DOM
"""
from __future__ import annotations

import numpy as np
from rasterio.features import rasterize
from scipy import ndimage
from shapely.geometry import Polygon, mapping

import config
from common import read_json, transformer, write_json
from geo import grid_shape, grid_transform

DERIVED = config.RAW / "derived"


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    g05 = dict(core, res=0.5)
    doc = read_json(config.RAW / "osm" / "buildings.json")
    t = transformer(config.CRS_WGS84, config.CRS_PROJECT)
    polys: list[tuple[int, Polygon]] = []
    for el in doc["elements"]:
        geom = el.get("geometry") or []
        if len(geom) < 4:
            continue
        pts = [t.transform(p["lon"], p["lat"]) for p in geom]
        poly = Polygon(pts)
        if poly.is_valid and poly.area > 4.0:
            polys.append((el["id"], poly))
    shape = grid_shape(g05)
    mask = rasterize(((mapping(p), 1) for _, p in polys), out_shape=shape,
                     transform=grid_transform(g05), fill=0, dtype="uint8").astype(bool)
    mask = ndimage.binary_dilation(mask, iterations=3)  # 1.5 m
    np.save(DERIVED / "building_mask_05.npy", mask)

    dgm = np.load(DERIVED / "dgm_core_05.npy")
    dom = np.load(DERIVED / "dom_core_05.npy")
    out = []
    for osm_id, p in polys:
        # roof height: 90th percentile of DOM-DGM on a 5x5 sample grid inside the bbox
        minx, miny, maxx, maxy = p.bounds
        gx, gy = np.meshgrid(np.linspace(minx, maxx, 7)[1:-1], np.linspace(miny, maxy, 7)[1:-1])
        cols = ((gx - core["e0"]) / 0.5).astype(int).ravel()
        rows = ((core["n0"] + core["size_z"] - gy) / 0.5).astype(int).ravel()
        ok = (cols >= 0) & (cols < shape[1]) & (rows >= 0) & (rows < shape[0])
        if not ok.any():
            continue
        hgt = float(np.percentile((dom - dgm)[rows[ok], cols[ok]], 90))
        base = float(dgm[rows[ok], cols[ok]].min())
        out.append({"osm_id": osm_id, "base_y": round(base, 2), "height_m": round(max(hgt, 2.5), 1),
                    "points": [[round(x - core["e0"], 2), round(-(y - core["n0"]), 2)]
                               for x, y in list(p.exterior.coords)[:-1]]})
    write_json(config.OUT / "buildings.json", {
        "source": "© OpenStreetMap contributors (ODbL); heights from Land Tirol DOM-DGM (CC BY 4.0)",
        "fields": "points = [x, z] Godot coords, base_y = lowest ground (m), height_m = roof height",
        "buildings": out,
    })
    print(f"[buildings] {len(out)} buildings, mask {mask.mean() * 100:.1f} % of core")


if __name__ == "__main__":
    main()
