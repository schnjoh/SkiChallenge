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

## 4. Validierungs-Bot (Phase 4)

<!-- BOT-VALIDATION:BEGIN -->
_Automatisch erzeugt von `game/scripts/tools/validate_track.gd` am 2026-11-25._

**Ergebnis: bestanden** — Zeit 1:55.29, 41 Tore, 5 Zwischenzeiten.

| Prüfung | Bot | Ziel | |
|---|---|---|---|
| Ziel erreicht, kein Sturz | ja | ja | ✅ |
| Alle Tore | 41/41 | alle | ✅ |
| Zeit | 1:55.29 | 1:46.95–1:56.68 (1:50–2:00 × 0.972) | ✅ |
| Ø-Tempo (3D-Länge) | 100.6 km/h | 101–107 km/h (±3 %) | ✅ |
| Höchsttempo | 151.5 km/h | ≤ 153 km/h | ✅ |
| Spitzen-g (Boden) | 3.55 g bei s=94 | ≤ 3,8 g | ✅ |
| 100 km/h nach dem Start | 8.3 s (s=146 m) | ≈ 8,5 s | ✅ |
| Sprung Mausefalle | 41 m bei 96 km/h, Landung 1.1 m | 40–65 m | ✅ |
| Sprung Seidlalmsprung | 20 m bei 72 km/h, Landung 0.5 m | 15–45 m | ✅ |
| Sprung Hausbergkante | 31 m bei 75 km/h, Landung 0.8 m | 15–45 m | ✅ |
| Sprung Zielsprung | 49 m bei 126 km/h, Landung 0.5 m | 40–65 m | ✅ |
| Tempo Mausefalle | Ø 117 (112–123) km/h | 105–120 km/h ±15 % | ✅ |
| Tempo Karussell | Ø 65 (39–98) km/h | 60–80 km/h ±15 % | ✅ |
| Tempo Steilhang | Ø 77 (46–94) km/h | 90–100 km/h ±15 % | ✅ |
| Tempo Brückenschuss | Ø 96 (91–105) km/h | 90–110 km/h ±15 % | ✅ |
| Tempo Gschöss | Ø 108 (99–138) km/h | 90–110 km/h ±15 % | ✅ |
| Tempo Alte Schneise | Ø 104 (72–139) km/h | 110–125 km/h ±15 % | ✅ |
| Tempo Seidlalmsprung | Ø 98 (76–108) km/h | 80–90 km/h ±15 % | ✅ |
| Tempo Lärchenschuss | Ø 107 (100–114) km/h | 100–110 km/h ±15 % | ✅ |
| Tempo Oberhausberg | Ø 100 (75–112) km/h | 60–80 km/h ±15 % | ⚠️ |
| Tempo Hausbergkante | Ø 80 (66–99) km/h | 90–105 km/h ±15 % | ✅ |
| Tempo Traverse | Ø 111 (87–150) km/h | 90–105 km/h ±15 % | ✅ |
| Tempo Zielsprung | Ø 132 (134–139) km/h | 120–145 km/h ±15 % | ✅ |
| Determinismus (2 Läufe) | 115.2860 / 115.2860 s | identisch | ✅ |

Zwischenzeiten: 0:13.13, 0:33.05, 0:57.63, 1:21.24, 1:35.51

| Abschnitt | s | Zeit | Ø km/h | min | max |
|---|---|---|---|---|---|
| Start | 0–182 | 9.79 s | 67 | 22 | 119 |
| Mausefalle | 182–256 | 2.27 s | 117 | 112 | 123 |
| Kompression | 256–396 | 5.92 s | 85 | 37 | 112 |
| Karussell | 396–522 | 7.00 s | 65 | 39 | 98 |
| Steilhang | 522–710 | 8.82 s | 77 | 46 | 94 |
| Brückenschuss | 710–1046 | 12.54 s | 96 | 91 | 105 |
| Gschöss | 1046–1372 | 10.87 s | 108 | 99 | 138 |
| Alte Schneise | 1372–1598 | 7.80 s | 104 | 72 | 139 |
| Seidlalmsprung | 1598–2014 | 15.31 s | 98 | 76 | 108 |
| Lärchenschuss | 2014–2310 | 9.99 s | 107 | 100 | 114 |
| Oberhausberg | 2310–2420 | 3.96 s | 100 | 75 | 112 |
| Hausbergkante | 2420–2576 | 7.01 s | 80 | 66 | 99 |
| Traverse | 2576–2790 | 6.92 s | 111 | 87 | 150 |
| Zielhang | 2790–2950 | 4.43 s | 130 | 125 | 151 |
| Zielsprung | 2950–3060 | 3.00 s | 132 | 134 | 139 |

Flugphasen > 15 m: s=138 41 m (96 km/h, Landung 1.1 m), s=175 17 m (119 km/h, Landung 0.4 m), s=1209 19 m (100 km/h, Landung 0.1 m), s=1548 20 m (72 km/h, Landung 0.5 m), s=1571 28 m (76 km/h, Landung 0.6 m), s=1671 20 m (103 km/h, Landung 0.6 m), s=2414 31 m (75 km/h, Landung 0.8 m), s=2878 49 m (126 km/h, Landung 0.5 m)
<!-- BOT-VALIDATION:END -->
