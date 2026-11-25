"""Download the Streif race route relation from OpenStreetMap (Overpass API, ODbL)."""
from __future__ import annotations

import json

import config
from common import http_get

OUT = config.RAW / "osm" / "streif_relation.json"


def main(force: bool = False) -> None:
    if OUT.exists() and not force:
        print(f"[osm] cached {OUT}")
        return
    query = f"""[out:json][timeout:90];
relation({config.OSM_RELATION_ID})->.rel;
.rel out body;
way(r.rel);out geom;
node(r.rel);out body;"""
    last: Exception | None = None
    for ep in config.OVERPASS_ENDPOINTS:
        try:
            print(f"[osm] querying {ep}")
            raw = http_get(ep, method="POST", data={"data": query}, retries=3, timeout=120)
            doc = json.loads(raw)
            kinds = [e["type"] for e in doc.get("elements", [])]
            if "relation" not in kinds or "way" not in kinds or "node" not in kinds:
                raise RuntimeError(f"incomplete response: {set(kinds)}")
            OUT.parent.mkdir(parents=True, exist_ok=True)
            OUT.write_bytes(raw)
            print(f"[osm] saved {len(doc['elements'])} elements -> {OUT}")
            return
        except Exception as exc:  # try next mirror
            last = exc
            print(f"[osm] {ep} failed: {exc}")
    raise RuntimeError(f"all Overpass endpoints failed: {last}")


if __name__ == "__main__":
    main()
