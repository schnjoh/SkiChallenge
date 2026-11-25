"""Download OSM building footprints inside the core extent (ODbL)."""
from __future__ import annotations

import json

import config
from common import http_get, read_json, transformer

OUT = config.RAW / "osm" / "buildings.json"


def main(force: bool = False) -> None:
    if OUT.exists() and not force:
        print(f"[osm-buildings] cached {OUT}")
        return
    core = read_json(config.RAW / "derived" / "extent.json")["core"]
    t = transformer(config.CRS_PROJECT, config.CRS_WGS84)
    lons, lats = zip(*[t.transform(core["e0"] + dx * core["size_x"], core["n0"] + dz * core["size_z"])
                       for dx in (0, 1) for dz in (0, 1)])
    bbox = f"{min(lats):.6f},{min(lons):.6f},{max(lats):.6f},{max(lons):.6f}"
    query = f'[out:json][timeout:120];way["building"]({bbox});out geom;'
    last: Exception | None = None
    for ep in config.OVERPASS_ENDPOINTS:
        try:
            print(f"[osm-buildings] querying {ep}")
            raw = http_get(ep, method="POST", data={"data": query}, retries=3, timeout=180)
            doc = json.loads(raw)
            if not doc.get("elements"):
                raise RuntimeError("no buildings returned")
            OUT.write_bytes(raw)
            print(f"[osm-buildings] {len(doc['elements'])} buildings -> {OUT}")
            return
        except Exception as exc:
            last = exc
            print(f"[osm-buildings] {ep} failed: {exc}")
    raise RuntimeError(f"all Overpass endpoints failed: {last}")


if __name__ == "__main__":
    main()
