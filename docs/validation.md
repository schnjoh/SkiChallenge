# Validierung

## 1. Gelände vs. Recherche (Phase 2)

Messung: `tools/pipeline/process_terrain.py` → `game/data/streif/line_stats.json` (Rennlinie auf der
Schneeoberfläche, 2-m-Raster). Referenz: `docs/streif-research.md`. Automatisch geprüft in
`tools/pipeline/check_outputs.py` und `game/tests/unit/test_track_data.gd`.

| Größe | Spiel (gemessen) | Recherche | Abweichung | Bewertung |
|---|---|---|---|---|
| Starthöhe | 1663,0 m | 1665 m | −2 m | ok (Starthaus steht erhöht) |
| Zielhöhe | 805,1 m | 805 m | 0 m | ok (Schnitt der Linie bei 805 m) |
| Höhendifferenz | 857,9 m | 860 m | −0,2 % | ok |
| Länge 3D | 3220 m | 3312 m | −2,8 % | ok (±5 %); Linie geglättet, Kurven innen |
| Länge horizontal | 3060 m | – | – | Bezug für Abschnitts-s |
| Ø-Gefälle | 28,0 % | 27 % | +1 Pp | ok |
| Max. Gefälle (10 m) | 77,2 % bei s = 140 m | 85 % (Mausefalle) | −8 Pp | **offen**: Kante in Phase 4 als Schneeform (`jumps.json`) |
| Max. Gefälle (50 m) | 71,2 % bei s = 138 m | – | – | Mausefalle-Absprung, Lage stimmt |

Konsequenz für den Bot (Phase 4): Zielzeit wird mit 3220/3312 = 0,972 skaliert →
**1:47–1:57** statt 1:50–2:00.

Heightmap-Treue: `height.r32` minus 0,3 m Schnee entspricht außerhalb des Pistenkorridors exakt dem
Roh-DGM (0,000 m Abweichung, 3894 Stichproben). Terrain3D-Vertices = `HeightField`
(`test_world_build.gd`, Toleranz 1 cm).

## 2. Sichtprüfung (Screenshots `docs/img/tour_*.png`)

Feste Kameras: Start, Mausefalle, Steilhang, Hausbergkante, Ziel, Übersicht
(`game/scenes/tools/screenshot_tour.tscn`). Gefundene und behobene Fehler:

1. Häuser in Kitzbühel als Wald klassifiziert → OSM-Gebäudemaske (Phase 1).
2. Gelände grau/dunkel, Albedo der CC0-Sets sehr unterschiedlich → Albedo auf Zielhelligkeit normiert.
3. Fernring-Noise sah nach Camouflage aus, HDRI-Boden als endlose Ebene → Fern- (4 m) und
   Horizontring (32 m, 30 km) aus echten Daten mit gleicher Winter-Einfärbung.
4. Blockige Fels-Flecken am Start (Kies/Beton) → Fels nur noch über Neigung > 40°.
5. Schachbrett statt Textur → nach Pipeline-Läufen fehlte der Reimport (`godot --headless --import`).
6. HDRI-Waldhügel über den echten Bergen → eigener Sky-Shader, HDRI erst ab 12° Elevation.

## 3. Performance-Stichprobe (Zielhardware Iris Xe, 1080p, volle Qualität, VSync aus)

| Ansicht | fps |
|---|---|
| Start | 49 |
| Mausefalle | 51 |
| Steilhang | 54 |
| Hausbergkante | 54 |
| Ziel | 60 |
| Übersicht (650 m hoch) | 43 |

Aufbau der Welt: ~2,5 s. Optimierung auf stabile 60 fps (mittlere Einstellungen) in Phase 6.
