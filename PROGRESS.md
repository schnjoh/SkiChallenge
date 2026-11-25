# PROGRESS.md

## Stand (2026-11-25)
- Phase 0 – Design & Setup: **abgeschlossen** (Review durchgeführt, gepusht).
- **Phase 1 – Datenpipeline: inhaltlich fertig, Phasenabschluss offen** (Review-Sub-Agent fehlt noch).
- Phase 2–6: offen.

## Exakt nächster Schritt
1. Phase-1-Review-Sub-Agent starten (Pipeline-Code `tools/pipeline/*`, Ausgaben `game/data/streif/*`,
   Vorschaubilder `docs/img/`), Funde beheben, die 4 Ruff-Stilfunde (s. u.) mit beheben.
2. CREDITS.md/credits.json um konkrete Datensätze ergänzen (WCS-Coverages, Orthofoto `Aktuell_RGB`,
   OSM-Gebäude) → Commit → Push → Statusmeldung Phase 1.
3. Dann Phase 2: Godot-Loader für `meta.json`/`height.r32` (`FileAccess` + `Image.create_from_data(FORMAT_RF)`),
   Terrain3D-Import (3×3 Regionen à 1024 m, `vertex_spacing` 1.0, Position `(0,0,-3072)`),
   GUT-Test der Weltabbildung (Start bei x≈1022, z≈−542, y≈1663).

## Erledigt
- Phase 0: Godot 4.7.2 + git-lfs nach ~/.local ohne sudo; venv mit rasterio (GDAL 3.12);
  Godot-Projekt `game/` mit GUT 9.7.1 + Terrain3D 1.1.0; Recherche, DESIGN, CLAUDE, CREDITS, README.
- Phase 1 (`tools/pipeline/`, Einstieg `run_all.py`):
  - `fetch_osm.py` Relation 12870777 (25 Elemente), `process_line.py` Linie EPSG:31255 + Extents
    (Kern 3072×3072 m ab E0=−73592, N0=254075; Fern 8000×8000 m, 5 m).
  - `fetch_terrain.py` WCS DGM+DOM 50 cm (18 Kacheln) + Fernring; `fetch_ortho.py` Orthofoto 0,5 m (16 Kacheln).
  - `process_terrain.py` → `height.r32` (Schneeoberfläche: Korridor geglättet σ 1,5 m, +0,3 m),
    `far_height.r32`, `meta.json`, `line.json` (2 m, geglättet, am Ziel bei 805 m geschnitten),
    `sections.json` (15 Abschnitte inkl. Start, Breiten tunebar), `line_stats.json`.
  - `fetch_osm_buildings.py` + `process_buildings.py` → Gebäudemaske, `buildings.json` (1643 Gebäude).
  - `process_trees.py` → `trees.bin` (98 420 Bäume, Median 23,9 m); `process_splat.py` → `splat.png`, `colormap.jpg`.
  - `check_outputs.py`: 19 Prüfungen **alle grün**. `preview.py` → `docs/img/` (visuell geprüft).
- Messwerte vs. Recherche: Start 1663 m (1665), Ziel 805 m (805), Δh 858 m (860), Länge 3D 3220 m
  (3312, −2,8 %), Ø-Gefälle 28 % (27 %), Max. 77 % über 10 m bei s=140 (85 % Mausefalle).

## Build / Lint / Tests (Stand dieses Commits)
- Godot-Import: fehlerfrei. GUT: 5/5 grün. Smoketest: 0 ERROR/WARNING. Python compileall: ok.
- `check_outputs.py`: PASSED.
- **Ruff (rot, nicht gefixt):** `preview.py:54,55` E731 (lambda-Zuweisung), `process_line.py:24` E501,
  `run_all.py:18` E501. Rein stilistisch.

## Offene Bugs / Auffälligkeiten
- Maximalgefälle Mausefalle 77 % statt 85 %: DGM ist Sommergelände; Kante in Phase 4 über `jumps.json` modellieren.
- Pistenbreiten in `config.SECTION_WIDTHS_M` geschätzt (keine Quelle) → in Phase 2 per Screenshot prüfen.
- Splat „Fels“ heuristisch (Neigung > 38° oder graue, helle, nicht grüne Pixel) – visuell prüfen.
- Forststraßen (Brückenschuss/Gschöss) nur über die Korridor-Glättung ausgerundet, kein eigenes Profil.
- Flugjahr der ALS-Daten liefert der WCS nicht → in CREDITS als „aktueller Stand WCS“ ausweisen.
- `fetch_osm.py` prüft einen vorhandenen Cache nicht auf Vollständigkeit (ein alter, unvollständiger
  Cache würde übernommen; aktueller Cache ist vollständig).
- Export-Ausschlüsse (GUT, Terrain3D csharp/extras) noch nicht gesetzt (Phase 6).

## Entscheidungen
- **Spieltitel „Schussfahrt“** (eigener Begriff, markenfrei).
- **Repo heißt `schnjoh/SkiChallenge`** (vom Nutzer so angelegt, Schreibweise mit „e“).
- Godot-Projekt in `game/` (nicht im Root), Pipeline schreibt direkt nach `game/data/`.
- Python: rasterio-Wheels statt System-GDAL (kein sudo). Ruff als Linter.
- GUT 9.7.1 (einzige 4.7-kompatible), Terrain3D 1.1.0 (4.5–4.8); nur Linux/Windows-x86_64-Binaries.
- CRS **EPSG:31255** (Tiroler ALS Zone M31); Orthofoto (EPSG:31254) wird umprojiziert.
- Terrain-Download per WCS 1.0.0, Kacheln um −0,25 m verschoben → native Pixelmitten, kein Server-Resampling.
- Kern auf Terrain3D-Regionen ausgerichtet: 3×3 × 1024 m, 1 m Auflösung; Fernring 8 km, 5 m (aus 50-cm-Coverage mit resx=5).
- Heightmaps als roh float32 (`.r32`) statt EXR; Abbildung `x=E−E0, y=h, z=−(N−N0)`, Zellmitten.
- Rennlinie: OSM-Relation 12870777, Resampling 2 m, Gauß-Glättung σ 10 m, Schnitt bei 805 m.
- Schneeoberfläche: im Korridor (+10 m weicher Rand) Gauß σ 1,5 m, überall +0,3 m Schnee.
- Bäume: lokale Maxima der Vegetationshöhe (Fenster 3 m) > 3 m, außerhalb Korridor + 4 m und
  außerhalb OSM-Gebäuden (+1,5 m). **Gebäude-Heuristik (Dachrauheit) verworfen**, weil Satteldächer
  als Wald erkannt wurden → OSM-Gebäudeumrisse als Maske (sichtbarer Fehler in der Vorschau, behoben).
- Splat: R Schnee, G Piste (Korridor, 6 m weicher Rand), B Wald (Vegetation > 3 m), A Fels; Farbkarte
  winterlich umgefärbt (Orthofotos sind Sommerbilder).
- Maximalgefälle 85 % der Mausefalle zugeordnet (Mehrheit der Quellen).
- Bot-Ziel 1:50–2:00 skaliert auf Spiellänge + Ø 101–107 km/h + Abschnittstempi.
- Physik-Kollision analytisch über Heightmap (Dreiecksteilung wie Terrain3D), Abhebe-Hysterese.
- User-Presets als JSON (keine .tres aus user://), Physik 120 Hz, Jolt, MSAA aus.
- Bäume als eigener Low-Poly-Nadelbaum per Code (CC0-Modelle ohne stabile Direktlinks).
- Phasenstatus-Meldungen max. 5 Zeilen; Review-Sub-Agent am Ende jeder Phase.
