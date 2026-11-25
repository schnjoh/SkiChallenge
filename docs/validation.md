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

## 3. Performance (Zielhardware Intel Iris Xe, 1920×1080, VSync aus)

Messung: `scenes/tools/perf_run.tscn` – das echte Spiel, der Bot fährt die ganze Strecke in Echtzeit
(1:54 min), Frame-Zeiten je Abschnitt in `docs/img/perf_<preset>.txt`.

| Preset (Einstellungen) | Ø fps | 1 %-Low | GPU Ø |
|---|---|---|---|
| niedrig (Skala 0,67 FSR, Sicht 0,5, Bäume 0,3, Schatten aus) | 101 | 58 | 9,5 ms |
| **mittel** (Standard: Skala 0,8 FSR, Sicht 0,7, Bäume 0,5, Schatten mittel) | 60–74 | 40–45 | 13–16 ms |
| hoch (Skala 1,0, Sicht 1,0, Bäume 1,0, Schatten hoch, MSAA 2×) | 44 | 29 | 22 ms |

Befunde und Maßnahmen (Phase 6):
1. GPU-gebunden; die Auflösungsskala wirkt kaum, der Sonnen-Schattenpass dominiert. „Mittel“: kein
   Gelände-Eigenschatten, keine Baumschatten, eine Kaskade, Atlas 2048, Distanz 120 m, Clipmap 32.
2. Skispur wurde pro Sample komplett neu gebaut → in Abschnitte zerlegt (konstante Kosten).
3. Messungen streuen auf dem Laptop thermisch bedingt um ±15 % bei identischer Konfiguration.

**Ergebnis:** Das Ziel „stabile 60 fps bei mittleren Einstellungen“ wird **nicht ganz** erreicht
(Ø über 60, Einbrüche auf ~40–45 fps im unteren Streckenteil). Stabile 60 fps (1 %-Low 58) liefert das
Preset „niedrig“. Weitere Hebel (offen): eigener, schlankerer Terrain-Shader (Terrain3D tastet pro Pixel
4× Control-Map mit je zwei Materialien ab), Impostor-Bäume, statische Schattenkarte für das Gelände.

## 4. Validierungs-Bot (Phase 4)

<!-- BOT-VALIDATION:BEGIN -->
_Automatisch erzeugt von `game/scripts/tools/validate_track.gd` am 2026-11-25._

**Ergebnis: bestanden** — Zeit 1:54.34, 41 Tore, 5 Zwischenzeiten.

| Prüfung | Bot | Ziel | |
|---|---|---|---|
| Ziel erreicht, kein Sturz | ja | ja | ✅ |
| Alle Tore | 41/41 | alle | ✅ |
| Zeit | 1:54.34 | 1:46.95–1:56.68 (1:50–2:00 × 0.972) | ✅ |
| Ø-Tempo (3D-Länge) | 101.4 km/h | 101–107 km/h | ✅ |
| Netz-/Baumkontakte | 0 | 0 | ✅ |
| Höchsttempo | 152.8 km/h | ≤ 153 km/h | ✅ |
| Spitzen-g (Boden) | 3.60 g bei s=2758 | ≤ 3,8 g | ✅ |
| 100 km/h nach dem Start | 8.2 s (s=144 m) | ≈ 8,5 s | ✅ |
| Sprung Mausefalle | 45 m bei 94 km/h, Landung 1.5 m | 40–65 m | ✅ |
| Sprung Seidlalmsprung | 26 m bei 76 km/h, Landung 0.8 m | 15–45 m | ✅ |
| Sprung Hausbergkante | 31 m bei 80 km/h, Landung 1.2 m | 15–45 m | ✅ |
| Sprung Zielsprung | 53 m bei 128 km/h, Landung 0.6 m | 40–65 m | ✅ |
| Tempo Mausefalle | Ø 117 (113–123) km/h | 105–120 km/h ±15 % | ✅ |
| Tempo Karussell | Ø 65 (40–98) km/h | 60–80 km/h ±15 % | ✅ |
| Tempo Steilhang | Ø 77 (45–94) km/h | 90–100 km/h ±15 % | ✅ |
| Tempo Brückenschuss | Ø 98 (92–108) km/h | 90–110 km/h ±15 % | ✅ |
| Tempo Gschöss | Ø 111 (102–140) km/h | 90–110 km/h ±15 % | ✅ |
| Tempo Alte Schneise | Ø 106 (73–141) km/h | 110–125 km/h ±15 % | ✅ |
| Tempo Seidlalmsprung | Ø 98 (76–109) km/h | 80–90 km/h ±15 % | ✅ |
| Tempo Lärchenschuss | Ø 109 (103–116) km/h | 100–110 km/h ±15 % | ✅ |
| Tempo Oberhausberg | Ø 100 (79–114) km/h | 60–80 km/h ±15 % | ⚠️ |
| Tempo Hausbergkante | Ø 78 (66–97) km/h | 90–105 km/h ±15 % | ✅ |
| Tempo Traverse | Ø 112 (87–152) km/h | 90–105 km/h ±15 % | ✅ |
| Tempo Zielsprung | Ø 133 (135–140) km/h | 120–145 km/h ±15 % | ✅ |
| Determinismus (2 Läufe) | 114.3450 / 114.3450 s | identisch | ✅ |

Zwischenzeiten: 0:13.09, 0:32.97, 0:57.03, 1:20.42, 1:34.62

| Abschnitt | s | Zeit | Ø km/h | min | max |
|---|---|---|---|---|---|
| Start | 0–182 | 9.74 s | 67 | 22 | 119 |
| Mausefalle | 182–256 | 2.27 s | 117 | 113 | 123 |
| Kompression | 256–396 | 5.91 s | 85 | 38 | 113 |
| Karussell | 396–522 | 6.98 s | 65 | 40 | 98 |
| Steilhang | 522–710 | 8.79 s | 77 | 45 | 94 |
| Brückenschuss | 710–1046 | 12.31 s | 98 | 92 | 108 |
| Gschöss | 1046–1372 | 10.60 s | 111 | 102 | 140 |
| Alte Schneise | 1372–1598 | 7.67 s | 106 | 73 | 141 |
| Seidlalmsprung | 1598–2014 | 15.23 s | 98 | 76 | 109 |
| Lärchenschuss | 2014–2310 | 9.76 s | 109 | 103 | 116 |
| Oberhausberg | 2310–2420 | 3.96 s | 100 | 79 | 114 |
| Hausbergkante | 2420–2576 | 7.19 s | 78 | 66 | 97 |
| Traverse | 2576–2790 | 6.88 s | 112 | 87 | 152 |
| Zielhang | 2790–2950 | 4.40 s | 131 | 126 | 153 |
| Zielsprung | 2950–3060 | 2.98 s | 133 | 135 | 140 |

Flugphasen > 15 m: s=129 45 m (94 km/h, Landung 1.5 m), s=171 23 m (117 km/h, Landung 1.0 m), s=1540 26 m (76 km/h, Landung 0.8 m), s=1571 31 m (77 km/h, Landung 0.9 m), s=1671 20 m (103 km/h, Landung 0.6 m), s=2404 31 m (80 km/h, Landung 1.2 m), s=2867 53 m (128 km/h, Landung 0.6 m)
<!-- BOT-VALIDATION:END -->
