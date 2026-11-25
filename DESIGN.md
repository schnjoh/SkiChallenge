# DESIGN.md – Schussfahrt (Projekt SkiChallange)

## 1. Vision
Arcadiges, aber physikalisch glaubwürdiges Abfahrtsspiel auf **echten Weltcup-Strecken**.
Gameplay-Muster wie die klassischen Browser-Skispiele: eine Taste für die Hocke, Lenken mit
Pfeilen, das Ziel ist die schnellste Zeit, das Lesen der Linie und saubere Sprünge.
Erste Strecke: die **Streif** in Kitzbühel, gebaut aus offenen Geländedaten (Land Tirol, OSM).

**Titel:** *Schussfahrt*. Begründung: eigener, beschreibender deutscher Begriff, keine Marke und
kein Bezug auf Original-Spiel oder Event. Projekt-/Repo-Name bleibt `SkiChallange`.

Abgrenzung: kein Asset, Layout, Logo oder Sound aus dem Original-Spiel, keine Sponsor-/Eventmarken.
HUD und Kamera orientieren sich nur funktional an `reference/` (was angezeigt wird, nicht wie).

## 2. Zielwerte aus der Recherche (`docs/streif-research.md`)
| Größe | Ziel | Toleranz / Einsatz |
|---|---|---|
| Streckenlänge | 3312 m (offiziell), OSM-Linie Start → Ziel ≈ 3090 m horizontal | Messung Phase 2: ±5 % gegen offiziellen Wert über 3D-Länge |
| Start / Ziel / Δh | 1665 m / 805 m / 860 m | DGM ±15 m (Starthaus steht erhöht) |
| Max. Gefälle | 85 % (40,4°), Mausefalle | DGM 50 cm sollte ≥ 70 % zeigen; sonst Schneeform nachmodellieren |
| Mittleres Gefälle | 27 % | ±3 Prozentpunkte |
| Siegerzeit (volle Strecke) | 1:52–1:57, Rekord 1:51,58 | **Bot: 1:46–2:05 (±10 % um ~1:55)** |
| Ø-Tempo | 101–107 km/h | Plausibilitätscheck Bot |
| Höchsttempo | 140–145 km/h im Zielschuss, Rekord 153 | Bot ≤ 155 km/h |
| 100 km/h nach dem Start | nach ≈ 8,5 s | Physik-Test |
| Mausefalle-Sprung | 50–60 m bei ~105–120 km/h | Bot-/Physik-Test |
| Zielsprung | 50–60 m | Bot |
| Lastspitzen | 3,0–3,5 g (Karussell, Hausberg-Kompression) | Sturzschwelle Überlast > ~4,5 g (tunebar) |
| Sturz bei Landung | ab ~2,5 m äquivalenter Fallhöhe auf flacher Landung | tunebar |

## 3. Abschnitte (Reihenfolge, Distanz s ab Start entlang OSM-Linie)
Start (0) → Mausefalle (183, Sprung, max. Gefälle) → Kompression (258) → Karussell (402,
180°-Rechts) → Steilhang (534, Hangschräge, Ausfahrt) → Brückenschuss (724, Gleiten) →
Gschöss (1061, Gleiten, kleiner Sprung) → Alte Schneise (1388, Sprung, Schräge rechts) →
Seidlalmsprung (1615) → Seidlalm-S (rechts/links) → Lärchenschuss (2035, Wald, ~90°-Kurve) →
Oberhausberg (2330, flach) → Hausbergkante (2443, Sprung rechts) → Hausberg-Kompression
(Linkskurve, 3,5 g) → Querfahrt (2602, Wellen) → Zielschuss (2816, > 140 km/h) →
Zielsprung (2976) → Ziel (~3090).
**Zwischenzeiten** (5): Mausefalle-Ausgang (~300), Steilhang-Ausfahrt (~700),
Alte Schneise (~1400), Lärchenschuss (~2050), Hausbergkante (~2450); Ziel.

## 4. Architektur
```
tools/pipeline (Python, rasterio/GDAL)          game/ (Godot 4.7, GDScript statisch typisiert)
  fetch_*  → data/raw (gitignored)                data/streif/  heightmap, splat, trees, line, gates
  process_* → game/data/streif/*  ───────────►    scripts/terrain  Terrain laden, Bäume (MultiMesh)
                                                  scripts/physics  SkiPhysics (pure), SkiTuning (Resource)
                                                  scripts/race     Tore, Zeitmessung, Ghost, Bestenliste, Bot
                                                  scripts/camera   Verfolger-/Helmkamera
                                                  scripts/ui       Menüs, HUD, Credits
                                                  scripts/debug    F1-Tuning-Menü, Tor-Editor
```

### 4.1 Koordinaten & Daten
- Projekt-CRS der Pipeline: Landes-CRS der Tiroler Daten (siehe `docs/data-sources.md`, voraussichtlich
  EPSG:31254 MGI/Austria GK West). Godot: 1 Einheit = 1 m, **+X = Ost, −Z = Nord, Y = Höhe ü. A.**
  minus `origin_height` (Metadaten), Ursprung = SW-Ecke des Ausschnitts → alle Werte in `meta.json`.
- Ausschnitt: Bounding Box der OSM-Linie + 300 m Rand. Auflösung im Spiel: Höhen 1 m (aus 50 cm
  gemittelt; 50 cm nur, wenn Performance reicht), Textur/Splat 1 m (Ortho bis 20 cm im Nahbereich optional).
- Dateien in `game/data/streif/`: `meta.json`, `height.exr` (32-bit float) bzw. Terrain3D-Regionen,
  `splat.png` (RGBA = Schnee/Piste/Wald/Fels), `ortho.jpg`, `trees.bin` (x,z,höhe), `line.json`
  (OSM-Linie, Godot-Koordinaten), `gates.json` (editierbar), `sections.json`.

### 4.2 Gelände
Primär **Terrain3D** (GDExtension, LOD-Clipmap, Splat/Control-Map). Fallback: eigene Chunk-Meshes
(64×64 m) mit 3 LOD-Stufen aus derselben Heightmap. Kollision: Physik fragt die Höhe/Normale
analytisch aus der Heightmap ab (bilinear), unabhängig vom Renderer. Dadurch ist die Physik headless
testbar und deterministisch. Modellierte Schneeformen (Sprungkanten) werden als Höhen-Offsets in die
Heightmap gebacken (Pipeline + `jumps.json`), sodass Render und Physik identisch bleiben.

### 4.3 Physikmodell (eigenes, kein Ragdoll)
Zustand: Position, Geschwindigkeit (3D), Ski-Richtung (Heading), Kantwinkel, Haltung (Hocke 0–1),
Bodenkontakt, Fluglage. Schritt mit fester Rate 120 Hz.
- **Schwerkraft** am Hang: Hangabtriebskomponente aus der Normale.
- **Ski-Querführung:** Geschwindigkeit wird in Ski-längs/quer zerlegt. Carven (|Lenken| klein,
  Kantwinkel aufgebaut): Querkomponente stark gedämpft → Kurve folgt Radius aus Kantwinkel
  (Ski-Taillierung). Driften (Lenken über Grip-Grenze oder Bremsen): Querkomponente erzeugt hohe
  Reibung → Tempoverlust.
- **Reibung:** Gleitreibung μ (Schnee) längs, separater Drift-Reibungsbeiwert quer.
- **Luftwiderstand:** F = ½ρ·cdA·v², cdA interpoliert zwischen Hocke (~0,15 m²) und aufrecht (~0,6 m²).
- **Sprünge:** Abheben, wenn die Normalkraft ≤ 0 (Gelände fällt schneller ab als Flugbahn).
  Vorspringen (Taste) gibt einen Impuls vor der Kante für einen kürzeren, flacheren Sprung. Flug: Gravitation +
  Luftwiderstand, Lage per Eingabe leicht korrigierbar. Landung: Aufprallgeschwindigkeit normal zum Hang
  → äquivalente Fallhöhe; > Schwelle oder Lage-Fehler > Schwelle → **Sturz**.
- **Überlast:** g-Kraft aus Normalkraft; über Schwelle für t > Δt → Sturz.
- Alle Beiwerte in `SkiTuning` (`res://resources/ski_tuning.tres`), F1-Menü mit Reglern, Presets
  in `user://presets/*.tres` + mitgelieferte Presets in `res://resources/presets/`.

### 4.4 Steuerung
| Aktion | Tastatur | Gamepad |
|---|---|---|
| Lenken | ← / → (A/D) | linker Stick X |
| Hocke | ↓ (S) / Leertaste halten | A / R2 |
| Aufrichten / Bremsen | ↑ (W) | B / L2 |
| Vorspringen | Strg / J | X |
| Neustart | R / Backspace | Y |
| Kamera wechseln | C | Back |
| Debug-Tuning | F1 | – |
| Debug-Strecke (Tore/Linie/Editor) | F2 | – |

### 4.5 Kamera
Verfolgerkamera: ~4,5 m hinter, ~1,8 m über dem Fahrer, Blick leicht voraus; gedämpftes Nachführen;
FOV 70° → 90° von 0 bis 150 km/h; leichtes Wackeln bei hohem Tempo/Landung. Optionale Helmkamera.

### 4.6 Fahrer
Selbstgebautes Low-Poly-Modell aus Primitiven (Rumpf, Kopf/Helm, Arme, Beine, Ski, Stöcke) mit
Code-Posen: Hocke, aufrecht, Kurvenlage (Rumpf-/Knie-Neigung nach Kantwinkel), Flug, Sturz
(physikbasiertes Rutschen + Rotation, kein Ragdoll). Schnittstelle `RiderVisual.apply_pose(state)`,
damit später ein geriggtes Modell eingesetzt werden kann.

### 4.7 Strecke & Rennen
- `gates.json`: Liste von Toren {id, position links/rechts (x,z), Typ}. Erzeugt per Skript aus der
  Rennlinie (Abstand ~60–120 m, dichter in Kurven), im F2-Editor per Maus verschiebbar und speicherbar.
- Torfehler (Tor nicht zwischen den Stangen passiert) → **DSQ**.
- Fangnetze (A-Netze: hohe Netze an Gefahrenstellen; B-Netze: Begrenzung), Zäune, Starthaus, Zielraum
  aus Primitiven/CC0-Modellen. Netze = Kollision → Sturz/Abprall.
- Zeitmessung: Start-Lichtschranke, Zwischenzeiten, Ziel; Rückstand zur Bestzeit.
- **Validierungs-Bot:** Pure-Pursuit-Autopilot auf der Rennlinie, headless, Ergebnis in
  `docs/validation.md`. Bedingungen: alle Tore, kein Sturz, Zeit 1:46–2:05.

### 4.8 Spielablauf (Phase 5)
Hauptmenü → Training (freies Fahren, Neustart an Abschnitten) / Rennen → Ergebnis →
Wiederholung (Replay aus aufgezeichneten Zuständen) / Ghost des besten Laufs (60 Hz-Samples,
`user://ghosts/`) / lokale Bestenliste (`user://leaderboard.json`). Grafikeinstellungen
(Auflösungsskala, Sichtweite, Baumdichte, Schatten, MSAA/FSR). Sounds CC0: Wind (tempoabhängig),
Kanten-Kratzen (Kantwinkel/Drift), Zuschauer (Zielnähe). Credits-Screen aus `credits.json`.

## 5. Performance-Budget (Intel Iris Xe, 1080p, mittel)
60 fps = 16,6 ms. Terrain3D-Clipmap; Bäume als MultiMesh mit 2 LOD (Mesh bis ~400 m,
Impostor/Billboard darüber, Sichtweite 1,5–2 km); Schatten: 1 gerichtetes Licht, 2 Kaskaden,
max. 300 m; kein SDFGI/SSR; Nebel/Atmosphäre über Sky-Shader; Auflösungsskala + FSR 1 als Regler.

## 6. Tests
GUT headless: Physik (freier Fall, Hangbeschleunigung, Endgeschwindigkeit Hocke/aufrecht,
Carven vs. Driften, Sprung-Reichweite, Landungs-/Überlast-Sturz), Heightmap-Sampling, Tor-Durchfahrt,
Zeitmessung, Ghost-Serialisierung, Bestenliste, Bot-Lauf (Integrationstest).
