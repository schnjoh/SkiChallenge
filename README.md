# SkiChallange – „Schussfahrt“

Ski-Abfahrtsspiel auf echten Geländedaten. Erste Strecke: die Streif in Kitzbühel.
Gelände aus offenen Daten des Landes Tirol (CC BY 4.0), Pistenlinie aus OpenStreetMap (ODbL).

> Status: in Entwicklung – siehe [PROGRESS.md](PROGRESS.md). Spec: [DESIGN.md](DESIGN.md).

## Setup
Voraussetzungen: Godot **4.7.2** (Befehl `godot`), Python 3.14 (getestet), `git-lfs`.
```bash
git lfs install && git clone git@github.com:schnjoh/SkiChallange.git && cd SkiChallange
cd game && godot --headless --import && godot      # Spiel starten
```
Tests: `cd game && godot --headless -s addons/gut/gut_cmdln.gd`

## Steuerung
| Aktion | Tastatur | Gamepad |
|---|---|---|
| Lenken | ← / → (A/D) | linker Stick |
| Hocke | ↓ (S) / Leertaste | A / R2 |
| Aufrichten / Bremsen | ↑ (W) | B / L2 |
| Vorspringen | Strg / J | X |
| Neustart | R / Backspace | Y |
| Kamera | C | Back |
| Handling-Debug / Strecken-Debug | F1 / F2 | – |

## Datenpipeline
Die verarbeiteten Daten liegen ab Phase 1 im Repo (`game/data/`, via Git LFS – ohne `git-lfs` lädt auch Terrain3D nicht). Zum Neuerzeugen:
```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
tools/.venv/bin/python tools/pipeline/run_all.py
```
Details und Endpunkte: [docs/data-sources.md](docs/data-sources.md).

## Lizenzen
Siehe [CREDITS.md](CREDITS.md). Keine Assets aus anderen Spielen.
