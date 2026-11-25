"""Download OSM building footprints inside the core extent (ODbL)."""
from __future__ import annotations

import json

import config
from common import overpass, read_json, transformer


def _bbox() -> str:
    core = read_json(config.RAW / "derived" / "extent.json")["core"]
    t = transformer(config.CRS_PROJECT, config.CRS_WGS84)
    lons, lats = zip(*[t.transform(core["e0"] + dx * core["size_x"], core["n0"] + dz * core["size_z"])
                       for dx in (0, 1) for dz in (0, 1)])
    return f"{min(lats):.6f},{min(lons):.6f},{max(lats):.6f},{max(lons):.6f}"


def out_path():
    # cache key = bbox, so a changed extent triggers a new download
    return config.RAW / "osm" / f"buildings_{_bbox().replace(',', '_')}.json"


def main(force: bool = False) -> None:
    out = out_path()
    if out.exists() and not force:
        print(f"[osm-buildings] cached {out.name}")
        return
    raw = overpass(f'[out:json][timeout:120];way["building"]({_bbox()});out geom;', ("way",))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(raw)
    print(f"[osm-buildings] {len(json.loads(raw)['elements'])} buildings -> {out.name}")


if __name__ == "__main__":
    main()
