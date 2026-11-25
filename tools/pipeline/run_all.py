"""Run the complete data pipeline (idempotent; downloads are cached in data/raw)."""
from __future__ import annotations

import time

import check_outputs
import fetch_ortho
import fetch_osm
import fetch_osm_buildings
import fetch_terrain
import preview
import process_buildings
import process_line
import pack_textures
import process_ortho
import process_rings
import process_shaping
import process_splat
import process_terrain
import process_trees

STEPS = [
    fetch_osm, process_line, fetch_terrain, fetch_ortho, fetch_osm_buildings,
    process_terrain, process_shaping, process_buildings, process_ortho, process_trees, process_splat, process_rings,
    pack_textures, preview,
]

if __name__ == "__main__":
    for step in STEPS:
        t = time.monotonic()
        print(f"=== {step.__name__}")
        step.main()
        print(f"    {time.monotonic() - t:.1f} s")
    raise SystemExit(check_outputs.main())
