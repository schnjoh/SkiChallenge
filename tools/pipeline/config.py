"""Central, versioned parameters of the data pipeline (Streif, Kitzbühel).

Everything that defines *what* is downloaded and *how* it is processed lives here,
so a run of ``run_all.py`` is reproducible.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw"
OUT = ROOT / "game" / "data" / "streif"

USER_AGENT = "SkiChallengePipeline/0.1 (open-data terrain pipeline)"
REQUEST_PAUSE_S = 2.0  # throttle between requests to public GIS servers

# --- CRS -------------------------------------------------------------------
CRS_WGS84 = "EPSG:4326"
CRS_PROJECT = "EPSG:31255"  # MGI / Austria GK Central (Tirol ALS zone M31)
CRS_ORTHO = "EPSG:31254"  # Tirol orthophotos only exist in GK West

# --- OpenStreetMap ---------------------------------------------------------
OSM_RELATION_ID = 12870777  # route=piste "Streif-Rennstrecke"
OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
# The OSM line continues past the finish into the valley; cut at this altitude (m).
FINISH_ALTITUDE_M = 805.0

# --- Extent ----------------------------------------------------------------
CORE_MARGIN_M = 300.0  # margin around the race line for the playable 1 m terrain
FAR_MARGIN_M = 3000.0  # margin of the low-res far-terrain ring
CORE_RES_M = 1.0  # game heightmap resolution
FAR_RES_M = 5.0
SPLAT_RES_M = 1.0
ORTHO_RES_M = 0.5  # downloaded orthophoto resolution
TERRAIN3D_REGION_M = 1024  # core extent is padded to a multiple of this

# --- Land Tirol services (CC BY 4.0, "Datenquelle: Land Tirol - data.tirol.gv.at") ---
WCS_TERRAIN = "https://gis.tirol.gv.at/arcgis/services/Service_Public/terrain/MapServer/WCSServer"
WCS_ORTHO = "https://gis.tirol.gv.at/arcgis/services/Service_Public/orthofoto/MapServer/WCSServer"
COV_DGM = "Gelaendemodell_50cm_M31"
COV_DOM = "Oberflaechenmodell_50cm_M31"
COV_ORTHO = "Aktuell_RGB"
WCS_MAX_TILE_M = 1200.0  # split requests into tiles of at most this size

# --- Processing ------------------------------------------------------------
TREE_MIN_HEIGHT_M = 3.0
TREE_PEAK_WINDOW_M = 3.0
TREE_CORRIDOR_CLEARANCE_M = 4.0
PISTE_DEFAULT_WIDTH_M = 30.0
SNOW_SMOOTH_SIGMA_M = 1.5
SNOW_DEPTH_M = 0.3

# Piste width (m) from each named OSM key point onward (relation node names).
# Real widths are not published; tuned values, editable later in game/data/streif/sections.json.
SECTION_WIDTHS_M = {
    "Start": 25.0, "Mausefalle": 30.0, "Kompression": 30.0, "Karussell": 35.0,
    "Steilhang": 50.0, "Brückenschuss": 15.0, "Gschöss": 18.0, "Alte Schneise": 35.0,
    "Seidlalmsprung": 35.0, "Lärchenschuss": 25.0, "Oberhausberg": 25.0,
    "Hausbergkante": 35.0, "Traverse": 40.0, "Zielhang": 60.0, "Zielsprung": 70.0,
}
LINE_SPACING_M = 2.0  # spacing of the exported race line
LINE_SMOOTH_SIGMA_M = 10.0
