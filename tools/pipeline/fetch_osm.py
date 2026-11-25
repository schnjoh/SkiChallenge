"""Download the Streif race route relation from OpenStreetMap (Overpass API, ODbL)."""
from __future__ import annotations

import json

import config
from common import overpass

OUT = config.RAW / "osm" / "streif_relation.json"


def _complete(path) -> bool:
    try:
        kinds = [e["type"] for e in json.loads(path.read_text())["elements"]]
        return {"relation", "way", "node"} <= set(kinds)
    except Exception:
        return False


def main(force: bool = False) -> None:
    if OUT.exists() and not force and _complete(OUT):
        print(f"[osm] cached {OUT}")
        return
    query = f"""[out:json][timeout:90];
relation({config.OSM_RELATION_ID})->.rel;
.rel out body;
way(r.rel);out geom;
node(r.rel);out body;"""
    raw = overpass(query, ("relation", "way", "node"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(raw)
    print(f"[osm] saved {len(json.loads(raw)['elements'])} elements -> {OUT}")


if __name__ == "__main__":
    main()
