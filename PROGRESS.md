# PROGRESS.md

## Stand
- **Phase 0 – Design & Setup: abgeschlossen** (Review durchgeführt, Funde behoben; Push blockiert)
- Phase 1 – Datenpipeline: als Nächstes

## Nächster Schritt
Phase 1: `tools/pipeline/config.py` (BBox aus OSM-Relation 12870777 + 300 m Rand, EPSG:31255),
`fetch_osm.py` → `fetch_terrain.py` (WCS 1.0.0, DGM+DOM 50 cm, gekachelt/gedrosselt) →
`fetch_ortho.py` → `process_*.py` → `game/data/streif/`.

## Erledigt
- Godot 4.7.2 + git-lfs nach ~/.local ohne sudo installiert; Python-venv mit rasterio (GDAL 3.12).
- Godot-Projekt in `game/`, GUT 9.7.1, Terrain3D 1.1.0 (Linux/Windows x86_64), 4 Tests grün.
- `docs/streif-research.md`, `docs/data-sources.md`, `DESIGN.md`, `CLAUDE.md`, `CREDITS.md`, `README.md`.

## Entscheidungen
- **Spieltitel „Schussfahrt“** (eigener Begriff, markenfrei). Repo bleibt „SkiChallange“.
- Godot-Projekt liegt in `game/` (nicht im Root), damit Godot venv/Rohdaten nicht scannt.
  Pipeline schreibt direkt nach `game/data/`.
- Python: rasterio-Wheels (bringen GDAL mit) statt System-GDAL – kein sudo nötig.
- GUT 9.7.1 (einzige 4.7-kompatible Version), Terrain3D 1.1.0 (unterstützt 4.5–4.8).
  Nur Linux/Windows-x86_64-Binaries eingecheckt (Exportziele).
- CRS: **EPSG:31255** (Tiroler ALS-Daten Zone M31); Ortho (EPSG:31254) wird umprojiziert.
- Terrain-Download per WCS 1.0.0 (`Gelaendemodell_50cm_M31`/`Oberflaechenmodell_50cm_M31`)
  statt Kachel-ZIPs: kein Zuschnitt nötig; Kacheln als Fallback.
- Rennlinie: OSM-Route-Relation 12870777 „Streif-Rennstrecke“ (10 Ways, grob → glätten),
  enthält 14 benannte Abschnittspunkte.
- Maximalgefälle 85 % der Mausefalle zugeordnet (Mehrheit der Quellen).
- Bot-Zielzeit 1:46–2:05 (±10 % um ~1:55, volle Strecke 1:52–1:57).
- Physik-Kollision analytisch über Heightmap-Sampling (deterministisch, headless testbar),
  Sprungkanten als Höhen-Offsets in die Heightmap gebacken.
- Orthofotos sind Sommeraufnahmen → nur als Klassifikationsbasis (Wald/Fels/Piste) und
  stark entsättigt/schneegetönt, nicht 1:1 als Textur.
- Bäume (Quaternius/Kenney) haben keine stabilen Direktlinks → eigener Low-Poly-Nadelbaum per
  Code/Primitiven als Standard; CC0-Modell optional.

- Review Phase 0 umgesetzt: verbindliche Bild↔Welt-Formel, Fernbereich (5 m-Ring), Dreiecks-Sampling
  wie Terrain3D, Abhebe-Hysterese, Tor-/DSQ-Logik, Physik-Startwerte, Bot-Kriterien (1:50–2:00 skaliert,
  Ø-Tempo, Abschnittstempi, Determinismus), Heightmaps als roh float32 (`.r32`) statt EXR,
  User-Presets als JSON, 120 Hz Physik + Jolt, MSAA aus, untypisierte Deklarationen = Fehler.
- Repo-Name „SkiChallange“ bleibt (Vorgabe des Nutzers); der Name taucht nicht im Spiel auf.
- Export-Ausschlüsse (GUT, Terrain3D csharp/extras) werden in Phase 6 mit den Export-Presets gesetzt.

## Offene Punkte / Blocker
- GitHub-Repo `schnjoh/SkiChallange` existiert noch nicht → Push blockiert (SSH-Zugang ok).
