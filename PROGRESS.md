# PROGRESS.md

## Stand (2026-11-25)
- Phase 0 – Design & Setup: **abgeschlossen**.
- Phase 1 – Datenpipeline: **abgeschlossen** (Review umgesetzt, 25/25 Selbstprüfungen grün, gepusht).
- **Phase 2 – Gelände in Godot: begonnen** (`HeightField` fertig + getestet).

## Exakt nächster Schritt (Phase 2)
1. `game/scripts/terrain/track_data.gd`: lädt `meta.json`, `line.json`, `sections.json`, `HeightField`
   (`height.r32`, Vertex-Konvention aus meta). GUT-Test: Start (x≈1022, z≈−542) → y≈1663.
2. `terrain_builder.gd`: Terrain3D per Code (region_size 1024, vertex_spacing 1), `import_images`
   mit height + control (`control.r32` → FORMAT_RF-Bytes) + colormap an `(0,0,-3072)`; 4 Texturen
   (Schnee, Piste, Waldboden, Fels; CC0 von Poly Haven/ambientCG via Asset-Sub-Agent).
3. Fernring-Mesh aus `far_height.r32` (Kern ausgespart), Bäume über `Terrain3DInstancer.add_transforms`
   (Low-Poly-Nadelbaum per Code), Himmel/HDRI, Nebel.
4. Screenshot-Tool: feste Kameras (Start, Mausefalle, Steilhang, Hausbergkante, Ziel) → `docs/img/`,
   ansehen, korrigieren. Messwerte gegen Recherche in `docs/validation.md`.

## Erledigt
- Phase 0: Godot 4.7.2 + git-lfs nach ~/.local ohne sudo; venv mit rasterio (GDAL 3.12);
  Godot-Projekt `game/` mit GUT 9.7.1 + Terrain3D 1.1.0; Recherche, DESIGN, CLAUDE, CREDITS, README.
- Phase 1 (`tools/pipeline/`, Einstieg `run_all.py`):
  - OSM-Relation 12870777 → Linie EPSG:31255; Kern 3072×3072 m (E0=−73592, N0=254075), Fern 9216 m @ 4 m.
  - WCS-Kacheln exakt auf Pipeline-Raster, Cache-Name enthält BBox/Auflösung, Manifest `derived/tiles.json`,
    Validierung von CRS/Bounds/Auflösung; Overpass mit Mirror-Fallback und `remark`-Ablehnung.
  - Ausgaben `game/data/streif/`: `height.r32`, `far_height.r32`, `control.r32`, `colormap.jpg`, `meta.json`,
    `line.json`, `sections.json`, `line_stats.json`, `trees.bin` (98 068 Bäume), `buildings.json` (1652).
  - Heightmap-Vertices gegen Roh-DGM verifiziert: Abweichung 0,000 m (3894 Stichproben).
- Phase 2: `HeightField` (Dreiecks-Interpolation wie Terrain3D, Normalen), 4 GUT-Tests.
- Messwerte vs. Recherche: Start 1663 m (1665), Ziel 805 m (805), Δh 858 m (860), Länge 3D 3220 m
  (3312, −2,8 %), Ø-Gefälle 28 % (27 %), Max. 77 % über 10 m bei s=140 (85 % Mausefalle).

## Build / Lint / Tests
- Godot-Import fehlerfrei, GUT 9/9 grün, Smoketest 0 Fehler, Ruff sauber, `check_outputs` 25/25.

## Offene Bugs / Auffälligkeiten
- Maximalgefälle Mausefalle 77 % statt 85 %: Kante in Phase 4 über `jumps.json` modellieren.
- Pistenbreiten in `config.SECTION_WIDTHS_M` geschätzt → in Phase 2 per Screenshot prüfen.
- Splat „Fels“ heuristisch – visuell prüfen. Forstwege nur über starke Glättung (σ 5 m) ausgerundet.
- Multipolygon-Gebäude (OSM-Relationen) fehlen in `buildings.json`.
- Export-Ausschlüsse/-Einschlüsse (GUT, Terrain3D csharp/extras; `data/*` als Nicht-Ressourcen) in Phase 6.

## Entscheidungen
- **Spieltitel „Schussfahrt“** (eigener Begriff, markenfrei).
- **Repo heißt `schnjoh/SkiChallenge`** (vom Nutzer so angelegt, Schreibweise mit „e“).
- Godot-Projekt in `game/` (nicht im Root), Pipeline schreibt direkt nach `game/data/`.
- Python: rasterio-Wheels statt System-GDAL (kein sudo). Ruff als Linter.
- GUT 9.7.1 (einzige 4.7-kompatible), Terrain3D 1.1.0 (4.5–4.8); nur Linux/Windows-x86_64-Binaries.
- CRS **EPSG:31255** (Tiroler ALS Zone M31); Orthofoto (EPSG:31254) wird umprojiziert.
- **Raster-Konvention „Sample = Vertex“** (statt Zellmitte): Terrain3D legt Pixel (c,r) auf Vertex (c,r) – per
  Probe-Skript gemessen; Halbmeter-Versatz zwischen Render und Physik damit ausgeschlossen (Review Phase 1).
- Terrain3D-Dreiecksdiagonale (x,z)→(x+1,z+1) aus `bake_mesh` gemessen; `get_height` interpoliert nicht.
- Terrain-Download per WCS 1.0.0 exakt auf dem Pipeline-Raster (Mosaik = Identität), 1 m = Mittel aus 2×2.
- Kern auf Terrain3D-Regionen ausgerichtet: 3×3 × 1024 m, 1 m; Fernring = Kern + 3 Regionen je Seite, 4 m.
- Heightmaps als roh float32 (`.r32`) statt EXR; Abbildung `x=E−E0, y=h, z=−(N−N0)`, Zellmitten.
- Rennlinie: OSM-Relation 12870777, Resampling 2 m, erst Zielschnitt bei 805 m (auf Rohlinie), dann Glättung
  σ 10 m inkl. 120 m Auslauf; Korridor läuft 120 m über das Ziel (Zielraum).
- Forstwegabschnitte (Brückenschuss, Gschöss) mit σ 5 m statt 1,5 m geglättet (Wegkanten).
- Schneeoberfläche: im Korridor (+10 m weicher Rand) Gauß σ 1,5 m, überall +0,3 m Schnee.
- Bäume: lokale Maxima der Vegetationshöhe (Fenster 3 m) > 3 m, außerhalb Korridor + 4 m und
  außerhalb OSM-Gebäuden (+1,5 m). **Gebäude-Heuristik (Dachrauheit) verworfen**, weil Satteldächer
  als Wald erkannt wurden → OSM-Gebäudeumrisse als Maske (sichtbarer Fehler in der Vorschau, behoben).
- Texturierung über **Terrain3D-Control-Map** (`control.r32`, Bitformat per Probe ermittelt) statt RGBA-Splat
  (Godot-Import hätte die Gewichte verfälscht); RGBA-Splat nur noch als Vorschau. Farbkarte
  winterlich umgefärbt (Orthofotos sind Sommerbilder).
- Maximalgefälle 85 % der Mausefalle zugeordnet (Mehrheit der Quellen).
- Bot-Ziel 1:50–2:00 skaliert auf Spiellänge + Ø 101–107 km/h + Abschnittstempi.
- Physik-Kollision analytisch über Heightmap (Dreiecksteilung wie Terrain3D), Abhebe-Hysterese.
- User-Presets als JSON (keine .tres aus user://), Physik 120 Hz, Jolt, MSAA aus.
- Bäume als eigener Low-Poly-Nadelbaum per Code (CC0-Modelle ohne stabile Direktlinks).
- Phasenstatus-Meldungen max. 5 Zeilen; Review-Sub-Agent am Ende jeder Phase.
