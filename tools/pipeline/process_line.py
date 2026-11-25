"""Build the ordered race line (EPSG:31255) from the OSM relation and derive the extents.

Outputs (intermediate, data/raw/derived/):
  line_31255.json  ordered polyline [[E, N], ...] + named key points
  extent.json      core (Terrain3D-aligned) and far grids in EPSG:31255
"""
from __future__ import annotations

import math

import config
from common import read_json, transformer, write_json

SRC = config.RAW / "osm" / "streif_relation.json"
DERIVED = config.RAW / "derived"


def chain_ways(ways: list[list[tuple[float, float]]]) -> list[tuple[float, float]]:
    """Concatenate ways in relation order, flipping each way so it continues the line."""
    line: list[tuple[float, float]] = list(ways[0])
    if len(ways) > 1:
        nxt = ways[1]
        # orient the first way so that its end touches the second way
        start_gap = min(_dist(line[0], nxt[0]), _dist(line[0], nxt[-1]))
        end_gap = min(_dist(line[-1], nxt[0]), _dist(line[-1], nxt[-1]))
        if start_gap < end_gap:
            line.reverse()
    for w in ways[1:]:
        seg = list(w)
        if _dist(line[-1], seg[-1]) < _dist(line[-1], seg[0]):
            seg.reverse()
        gap = _dist(line[-1], seg[0])
        if gap > 30.0:
            raise ValueError(f"ways do not connect (gap {gap:.1f} m)")
        line.extend(seg[1:] if gap < 0.5 else seg)
    return line


def _dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def polyline_length(pts: list[tuple[float, float]]) -> float:
    return sum(_dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def aligned_extent(min_e: float, min_n: float, max_e: float, max_n: float,
                   margin: float, step: float) -> dict[str, float]:
    """Extent around a bbox + margin, size padded to a multiple of ``step`` and centered."""
    w = max_e - min_e + 2 * margin
    h = max_n - min_n + 2 * margin
    size_x = math.ceil(w / step) * step
    size_z = math.ceil(h / step) * step
    cx, cy = (min_e + max_e) / 2, (min_n + max_n) / 2
    e0 = math.floor(cx - size_x / 2)
    n0 = math.floor(cy - size_z / 2)
    return {"e0": float(e0), "n0": float(n0), "size_x": float(size_x), "size_z": float(size_z)}


def main() -> None:
    doc = read_json(SRC)
    elems = doc["elements"]
    rel = next(e for e in elems if e["type"] == "relation")
    ways_by_id = {e["id"]: e for e in elems if e["type"] == "way"}
    nodes_by_id = {e["id"]: e for e in elems if e["type"] == "node"}
    to_proj = transformer(config.CRS_WGS84, config.CRS_PROJECT)

    ways: list[list[tuple[float, float]]] = []
    for m in rel["members"]:
        if m["type"] == "way":
            geom = ways_by_id[m["ref"]]["geometry"]
            ways.append([to_proj.transform(p["lon"], p["lat"]) for p in geom])
    line = chain_ways(ways)
    # Race direction: start is the highest/southern end (Hahnenkamm). Relation is oneway
    # in race direction; sanity-check with the known start (south end, smaller N).
    if line[0][1] > line[-1][1]:
        line.reverse()

    named = []
    for m in rel["members"]:
        if m["type"] == "node":
            n = nodes_by_id[m["ref"]]
            e, nn = to_proj.transform(n["lon"], n["lat"])
            named.append({"name": n.get("tags", {}).get("name", str(n["id"])), "e": e, "n": nn,
                          "osm_id": n["id"]})

    es = [p[0] for p in line]
    ns = [p[1] for p in line]
    core = aligned_extent(min(es), min(ns), max(es), max(ns), config.CORE_MARGIN_M,
                          config.TERRAIN3D_REGION_M)
    core["res"] = config.CORE_RES_M
    # far ring: core grown by whole Terrain3D regions -> far vertices coincide with core vertices
    m = config.FAR_MARGIN_REGIONS * config.TERRAIN3D_REGION_M
    far = {"e0": core["e0"] - m, "n0": core["n0"] - m, "size_x": core["size_x"] + 2 * m,
           "size_z": core["size_z"] + 2 * m, "res": config.FAR_RES_M}
    m = config.HORIZON_MARGIN_REGIONS * config.TERRAIN3D_REGION_M
    horizon = {"e0": core["e0"] - m, "n0": core["n0"] - m, "size_x": core["size_x"] + 2 * m,
               "size_z": core["size_z"] + 2 * m, "res": config.HORIZON_RES_M}

    write_json(DERIVED / "line_31255.json", {
        "crs": config.CRS_PROJECT, "source": f"OSM relation {config.OSM_RELATION_ID} (ODbL)",
        "points": [[round(e, 3), round(n, 3)] for e, n in line], "named": named,
    })
    write_json(DERIVED / "extent.json", {"crs": config.CRS_PROJECT, "core": core, "far": far,
                                         "horizon": horizon})
    print(f"[line] {len(line)} pts, {polyline_length(line):.0f} m, start {line[0]}, end {line[-1]}")
    print(f"[line] core {core}\n[line] far  {far}")


if __name__ == "__main__":
    main()
