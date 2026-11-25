# CLAUDE.md – Arbeitsregeln für SkiChallenge

Projekt: Ski-Abfahrtsspiel im Stil der alten Browser-Skispiele (eine Taste Hocke, Lenken, Bestzeit)
auf **echten Weltcup-Strecken aus echten Geländedaten**. Spieltitel: **Schussfahrt**.
Repo: `git@github.com:schnjoh/SkiChallenge.git` (Branch `main`). Erste Strecke: Streif, Kitzbühel.

**Nach jeder Kontext-Komprimierung und zu Beginn jeder Session zuerst `PROGRESS.md` lesen.**
Spec: `DESIGN.md`. Recherche: `docs/streif-research.md`, `docs/data-sources.md`.
Lizenzen: `CREDITS.md`. Dieses Dokument ersetzt den ursprünglichen Auftrag vollständig.

## Autonomie
- Alle Phasen selbstständig bis zum Ende durcharbeiten. Nur bei echten Blockern unterbrechen
  (fehlende Rechte, sudo, Login). Alles andere selbst entscheiden und in `PROGRESS.md` unter
  „Entscheidungen“ dokumentieren. Falls Fragen nötig: max. 3, jeweils mit Empfehlung.
- Commit nach jedem sinnvollen Schritt (Conventional Commits), Push auf `main` am Ende jeder Phase.
- Kein sudo verfügbar: Tools landen in `~/.local/bin` (godot 4.7.2, git-lfs), Python im venv.

## Rechtliches (hart)
- Keine Grafiken, Sounds, Modelle, Streckendaten oder Logos aus dem Original-Spiel
  (Greentube „Ski Challenge“). Keine Sponsor- oder Eventmarken (FIS-, Sponsor-, Rennlogos).
  Ortsnamen (Streif, Mausefalle …) sind ok. Der Repo-Name erscheint nicht im Spiel.
- `reference/` (gitignored) enthält Screenshots des Originals **nur als visuelle Vorlage** für Kamera,
  HUD und Stimmung. Nie laden, kopieren, nachzeichnen oder als Asset verwenden.
- Nur offene Daten und CC0-Assets (Engine/Addons MIT ok). Jede Quelle sofort in `CREDITS.md`
  **und** `game/data/credits.json` (Credits-Screen im Spiel). Pflicht-Attributionen:
  „Datenquelle: Land Tirol – data.tirol.gv.at“ (CC BY 4.0), „© OpenStreetMap contributors“ (ODbL;
  aus OSM abgeleitete Dateien sind ODbL), CC0-Quellen (Poly Haven, ambientCG, Kenney, Quaternius).

## Stack
- **Godot 4.7.2** (`godot`), **GDScript mit statischen Typen** (untypisierte Deklaration = Fehler).
  Projekt in `game/`. Physik 120 Hz, Jolt.
- Gelände: **Terrain3D 1.1.0** (`game/addons/terrain_3d`). Falls es Probleme macht: eigene
  Chunk-Meshes aus der Heightmap mit LOD.
- Datenpipeline: Python 3.14 + rasterio (bringt GDAL mit) in `tools/pipeline`, venv `tools/.venv`.
  Rohdaten `data/raw/` (gitignored), verarbeitete Daten nach `game/data/streif/` (committed, LFS).
- Tests: **GUT 9.7.1** headless. Große Binärdateien über **Git LFS** (`.gitattributes`).
- Zielhardware: Laptop Intel Iris Xe, 16 GB RAM → **stabile 60 fps bei 1080p, mittlere Einstellungen**.
- Export: Linux und Windows (x86_64).

## Architektur (Details: DESIGN.md)
- `game/scripts/{terrain,physics,race,camera,ui,debug}`, Szenen `game/scenes`, Tests `game/tests/unit`.
- Physik-/Spiellogik als reine Klassen (`RefCounted`/`Resource`) ohne Szenenabhängigkeit → headless
  testbar und deterministisch; Nodes sind dünne Adapter. Kollision analytisch über Heightmap-Sampling
  (gleiche Dreiecksteilung wie Terrain3D), Sprungkanten als Höhen-Offsets in die Heightmap gebacken.
- **Alle Handling-Werte** nur in `SkiTuning` (`res://resources/ski_tuning.tres`), live änderbar im
  Debug-Menü **F1**, Presets speicherbar (User-Presets als JSON in `user://presets/`).
- Koordinaten (verbindlich): 1 Einheit = 1 m, `x = E − E0`, `y = Höhe ü. A.`, `z = −(N − N0)`,
  EPSG:31255 (`meta.json`). Heightmap-Samples = **Vertices** wie Terrain3D: (col,row) bei
  `(world_min_x + col·res, world_min_z + row·res)`, Zeile 0 = Norden; Kern x 0…3071, z −3072…−1.
  Dreiecksdiagonale (x,z)→(x+1,z+1); Physik-Höhen nur über `HeightField`.
- Daten in `game/data/streif/`: `meta.json`, `height.r32` (float32, 3072², 1 m), `far_height.r32`
  (4 m, 9216 m), `line.json` (x,y,z,s), `sections.json`, `line_stats.json`, `trees.bin` (x,z,h float32),
  `control.r32` (Terrain3D-Control-Map, IDs 0 Schnee/1 Piste/2 Wald/3 Fels), `colormap.jpg`, `buildings.json`,
  später `gates.json`, `racing_line.json`, `jumps.json` (alle editierbar).

## Phasen
0. **Design & Setup** – Recherche (`docs/streif-research.md`), DESIGN.md, Scaffold. ✅
1. **Datenpipeline** – DGM+DOM 50 cm (Land Tirol, WCS) → Heightmap + Metadaten; Orthofoto → Splat/
   Farbkarte; Bäume = DOM−DGM > 3 m (MultiMesh-Positionen); Streif-Linie aus OSM (Overpass).
2. **Gelände in Godot** – Terrain3D mit Texturen, Bäume, Himmel/HDRI. Selbstprüfung: Screenshots
   von festen Kameras (Start, Mausefalle, Steilhang, Hausbergkante, Ziel) rendern, ansehen, Fehler
   korrigieren. Gemessene Länge/Höhendifferenz/Gefälle mit Recherche vergleichen.
3. **Fahrer & Physik** – eigenes Modell (kein Ragdoll): Tempo, Kantwinkel, Carven vs. Driften
   (unterschiedliche Reibung), Luftwiderstand Hocke vs. aufrecht, Hangabtrieb, Sprünge (Absprung,
   Vorspringen, Flug, Landung), Sturz bei zu harter Landung/Überlast. Steuerung Tastatur + Gamepad
   (Lenken, Hocke, Aufrichten/Bremsen, Vorspringen, Schnellneustart). Verfolgerkamera (hinter/über
   dem Fahrer, FOV steigt mit Tempo), optional Helmkamera. Low-Poly-Fahrer selbst gebaut, Posen
   (Hocke, Kurvenlage, Flug, Sturz) per Code, später gegen geriggtes Modell tauschbar.
   F1-Debug-Menü mit Reglern für alle `SkiTuning`-Werte, Presets speicherbar (Nutzer tunt selbst).
4. **Strecke** – Rennlinie aus OSM-Linie, Gefälle und Abschnitten; Tore per Skript in editierbarer
   Datei. Sprünge/Kanten als modellierte Schneeformen laut Recherche. A-/B-Netze, Zäune, Starthaus,
   Zielbereich. Zeitmessung mit Zwischenzeiten; Torfehler = DSQ. Debug-Ansicht (F2): Tore nummeriert,
   Rennlinie sichtbar, Tore per Maus verschieb- und speicherbar. **Validierungs-Bot** fährt headless
   die Ideallinie: fehlerfrei befahrbar, Zeit im Bereich realer Siegerzeiten (±10 %, Ziel 1:50–2:00
   skaliert auf Spiellänge), sonst Physik/Linie nachjustieren. Ergebnisse in `docs/validation.md`.
5. **Spielablauf** – Hauptmenü, Training und Rennen, Ghost des besten Laufs, lokale Bestenliste,
   Wiederholung, Sounds (CC0: Wind, Kanten, Zuschauer), Grafikeinstellungen, HUD (Tempo,
   Zwischenzeiten, Rückstand) nach Vorlage `reference/`, aber eigenes Design. Credits-Screen.
6. **Feinschliff** – Schnee-Shader (Spuren, Glanz), Zuschauer im Zielbereich, Performance auf
   Zielhardware messen/optimieren, Export Linux + Windows.
(Eine Phase 7 ist im Auftrag nicht definiert; nach Phase 6 gilt die Definition of Done.)

## Qualität pro Phase (Phasenende)
- Tests grün, Godot-Projekt startet ohne Fehler, Screenshots geprüft.
- Review-Sub-Agent am Phasenende, Funde beheben.
- `PROGRESS.md` aktualisieren, kurze Statusmeldung (max. 5 Zeilen), Push.

## Sub-Agents
Nur für: Recherche (Phase 0), Asset-Suche + Lizenzprüfung, Review. Nie zwei an denselben Dateien.

## Definition of Done
Die Streif ist von Start bis Ziel spielbar, mit Zeitmessung, Ghost und Bestenliste. Das F1-Debug-
Menü fürs Handling funktioniert. Der Bot validiert die Strecke. `README.md` erklärt Setup, Steuerung
und Datenpipeline.

## Befehle
```bash
cd game && godot --headless --import                        # Build / Import / Klassen-Cache
cd game && godot --headless -s addons/gut/gut_cmdln.gd      # alle GUT-Tests (Konfig .gutconfig.json)
cd game && godot --headless --quit-after 60 2>&1 | tee /tmp/smoke.log; ! grep -E "ERROR|WARNING" /tmp/smoke.log
cd game && godot                                            # Spiel starten
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
tools/.venv/bin/python tools/pipeline/run_all.py            # komplette Pipeline inkl. Selbstprüfung
tools/.venv/bin/python tools/pipeline/preview.py            # Vorschaubilder → docs/img/
tools/.venv/bin/ruff check tools/pipeline --select E,F,W --line-length 120   # Python-Lint
```

## Code-Regeln
- Statische Typen überall (`var x: float`, `-> void`, `Array[Vector3]`). Keine Magic Numbers in der
  Physik (alles in `SkiTuning`). Geschwindigkeiten intern m/s.
- Pipeline-Skripte reproduzierbar (Parameter in `tools/pipeline/config.py`), idempotent, cachen
  Downloads, drosseln Anfragen an Landesserver (2 s), Overpass mit Mirror-Fallback.
- Neue Pipeline-Ausgaben → Prüfung in `check_outputs.py` ergänzen.
- Rohdaten (`*.r32`, `*.json`, `*.bin`, `colormap.jpg`) lädt das Spiel per `FileAccess`/`Image.load_from_file`
  → im Export-Preset als Nicht-Ressourcen einschließen (`data/*`). Bilder, die roh bleiben sollen,
  bekommen eine `.import` mit `importer="keep"`.
- Terrain3D-Probe-Skripte (headless) müssen im ersten `_process`-Frame arbeiten, nicht in `_init` (hängt sonst).
