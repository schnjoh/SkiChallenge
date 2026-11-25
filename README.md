# SkiChallenge – „Schussfahrt“

Ski-Abfahrtsspiel auf **echten Geländedaten**: eine Taste für die Hocke, Lenken, die Linie lesen,
saubere Sprünge – und die Bestzeit. Erste Strecke: die **Streif** in Kitzbühel (Start 1663 m, Ziel 805 m,
3,2 km), gebaut aus offenen Daten des Landes Tirol (CC BY 4.0) und OpenStreetMap (ODbL).

Spec: [DESIGN.md](DESIGN.md) · Stand: [PROGRESS.md](PROGRESS.md) · Validierung: [docs/validation.md](docs/validation.md)

## Setup
Voraussetzungen: Godot **4.7.2** (Befehl `godot`), `git-lfs`; für die Datenpipeline Python 3.14.
```bash
git lfs install && git clone git@github.com:schnjoh/SkiChallenge.git && cd SkiChallenge
cd game && godot --headless --import    # einmalig: Import / Klassen-Cache
godot                                   # Spiel starten (Hauptmenü)
```
Ohne `git-lfs` fehlen Heightmaps und Texturen (Terrain3D lädt dann nicht).

## Spielen
- **Rennen**: Countdown, 41 Tore in fester Reihenfolge (ausgelassenes Tor = Disqualifikation),
  5 Zwischenzeiten mit Rückstand zur Bestzeit, Ghost des besten Laufs, lokale Bestenliste (Top 10).
- **Training**: Start an jedem Abschnitt (Mausefalle, Steilhang, Hausbergkante …), Q/E wechselt den Abschnitt.
- Nach dem Lauf: **Enter** = Wiederholung, **R** = Neustart, **Esc** = Pause (→ Hauptmenü).
- Gewertet (Bestenliste/Ghost) werden nur Rennen mit dem Standard-Handling; mit F1 geänderte Werte zählen nicht.
- Stürze: zu harte Landung, verkantet gelandet, Überlast, mit Tempo ins Netz.

### Steuerung
| Aktion | Tastatur | Gamepad |
|---|---|---|
| Lenken | ← / → (A/D) | linker Stick |
| Hocke | ↓ (S) / Leertaste | A / R2 |
| Aufrichten / Bremsen | ↑ (W) | B / L2 |
| Vorspringen (vor der Kante) | Strg / J | X |
| Neustart | R / Backspace | Y |
| Kamera (Verfolger/Helm) | C | Back |
| Wiederholung | Enter | rechter Stick (R3) |
| Training: Abschnitt zurück/vor | Q / E (Bild↑/↓) | LB / RB |
| Pause | Esc | Start |
| Handling-Tuning (Regler, Presets) | F1 | – |
| Strecken-Debug/-Editor | F2 | – |

**F1** zeigt alle Handling-Werte aus `SkiTuning` als Regler (live). Presets: mitgeliefert in
`game/resources/presets/*.json`, eigene werden als JSON unter `user://presets/` gespeichert.
**F2** zeigt Rennlinie (gelb), Mittellinie (cyan) und nummerierte Tore; Torstangen und Rennlinienpunkte
lassen sich mit der Maus ziehen und speichern (Entwicklungs-Checkout: `game/data/streif/`,
exportierter Build: `user://tracks/streif/`). Freie Kamera: rechte Maustaste + WASD/QE.

Einstellungen (Hauptmenü): Name, Auflösungsskala + FSR, Sichtweite, Baumdichte, Schatten, MSAA, VSync,
Vollbild, Lautstärke, Ghost, Kamera. Standard = „mittel“ (Zielhardware Intel Iris Xe, 1080p).

## Entwicklung
```bash
cd game
godot --headless -s addons/gut/gut_cmdln.gd                  # alle Tests (GUT)
godot --headless -s scripts/tools/validate_track.gd          # Validierungs-Bot → docs/validation.md
godot --headless -s scripts/tools/generate_track.gd -- --force   # racing_line.json + gates.json neu
godot --path . --display-driver x11 --resolution 1920x1080 res://scenes/tools/screenshot_tour.tscn
PERF_PRESET=medium godot --path . --display-driver x11 --resolution 1920x1080 res://scenes/tools/perf_run.tscn
mkdir -p ../export/linux ../export/windows
godot --headless --export-release "Linux" ../export/linux/Schussfahrt.x86_64
godot --headless --export-release "Windows" ../export/windows/Schussfahrt.exe
```
Export braucht die Godot-4.7.2-Exportvorlagen (`~/.local/share/godot/export_templates/4.7.2.stable/`).
Architektur: reine, deterministische Logikklassen (`SkiPhysics`, `RaceTimer`, `CourseBarriers`, `Ghost`,
`BotDriver` …) in `game/scripts/{physics,race,terrain}`, dünne Node-Adapter (`Rider`, `Game`, `World`).

## Datenpipeline
Die verarbeiteten Daten liegen im Repo (`game/data/streif/`, Git LFS). Neu erzeugen:
```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
tools/.venv/bin/python tools/pipeline/run_all.py     # Download (gecacht) + Verarbeitung + Selbstprüfung
cd game && godot --headless --import                 # danach immer neu importieren
```
Schritte: OSM-Linie (Overpass) → DGM/DOM 50 cm (WCS Land Tirol) → Heightmap 1 m + Fern-/Horizontring →
**Pistenpräparierung** (`process_shaping.py`, editierbar über `game/data/streif/jumps.json`: Profil glätten,
Sprünge Mausefalle/Seidlalm/Hausbergkante/Zielsprung als gebaute Schneeformen) → Orthofoto (winterlich) →
Bäume (DOM − DGM) → Control-Map/Splat → Texturen → Vorschaubilder → `check_outputs.py`.
Details: [docs/data-sources.md](docs/data-sources.md), Recherche: [docs/streif-research.md](docs/streif-research.md).

## Lizenzen
Siehe [CREDITS.md](CREDITS.md) (auch im Spiel unter „Credits“). Keine Assets, Daten oder Marken aus
anderen Spielen oder von Veranstaltern/Sponsoren.
