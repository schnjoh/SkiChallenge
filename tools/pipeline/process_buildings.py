"""Rasterise OSM building footprints (masks for trees/splat) and export buildings.json.

Outputs:
  data/raw/derived/building_mask_05.npy  bool, 0.5 m core grid (footprint dilated by 1.5 m)
  game/data/streif/buildings.json        footprints in Godot coords; base on the snow surface,
                                         roof height = p90 of DOM-DGM inside the polygon
Multipolygon buildings (OSM relations) are not included.
"""
from __future__ import annotations

import numpy as np
import shapely
from rasterio.features import rasterize
from scipy import ndimage
from shapely.geometry import Polygon, mapping

import config
import fetch_osm_buildings
from common import read_json, transformer, write_json
from geo import grid_shape, grid_transform, sample_bilinear, world_to_pixel

DERIVED = config.RAW / "derived"


def main() -> None:
    core = read_json(DERIVED / "extent.json")["core"]
    g05 = dict(core, res=0.5, anchor=core["res"])
    doc = read_json(fetch_osm_buildings.out_path())
    t = transformer(config.CRS_WGS84, config.CRS_PROJECT)
    polys: list[tuple[int, Polygon]] = []
    for el in doc["elements"]:
        geom = el.get("geometry") or []
        if len(geom) < 4:
            continue
        poly = Polygon([t.transform(p["lon"], p["lat"]) for p in geom])
        if poly.is_valid and poly.area > 4.0:
            polys.append((el["id"], poly))
    shape = grid_shape(g05)
    mask = rasterize(((mapping(p), 1) for _, p in polys), out_shape=shape,
                     transform=grid_transform(g05), fill=0, dtype="uint8").astype(bool)
    np.save(DERIVED / "building_mask_05.npy", ndimage.binary_dilation(mask, iterations=3))

    chm = np.load(DERIVED / "dom_core_05.npy") - np.load(DERIVED / "dgm_core_05.npy")
    height = np.fromfile(config.OUT / "height.r32", "<f4").reshape(grid_shape(core))
    out = []
    for osm_id, p in polys:
        minx, miny, maxx, maxy = p.bounds
        gx, gy = np.meshgrid(np.arange(minx, maxx, 0.5), np.arange(miny, maxy, 0.5))
        inside = shapely.contains_xy(p, gx, gy)
        if not inside.any():
            inside = np.ones_like(gx, bool)
        col, row = world_to_pixel(g05, gx[inside], gy[inside])
        ci, ri = np.round(col).astype(int), np.round(row).astype(int)
        ok = (ci >= 0) & (ci < shape[1]) & (ri >= 0) & (ri < shape[0])
        if not ok.any():
            continue
        roof = float(np.percentile(chm[ri[ok], ci[ok]], 90))
        ex, ey = np.asarray(p.exterior.coords).T
        base = float(sample_bilinear(height, core, ex, ey).min())
        out.append({"osm_id": osm_id, "base_y": round(base, 2), "height_m": round(max(roof, 2.5), 1),
                    "points": [[round(x - core["e0"], 2), round(-(y - core["n0"]), 2)]
                               for x, y in list(p.exterior.coords)[:-1]]})
    write_json(config.OUT / "buildings.json", {
        "source": "© OpenStreetMap contributors (ODbL); heights from Land Tirol DOM-DGM (CC BY 4.0)",
        "fields": "points = [x, z] Godot coords, base_y = lowest snow surface (m), height_m = roof height",
        "buildings": out,
    })
    print(f"[buildings] {len(out)} buildings, mask {mask.mean() * 100:.1f} % of core")


if __name__ == "__main__":
    main()
