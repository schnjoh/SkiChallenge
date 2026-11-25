# CLAUDE.md – Arbeitsregeln für SkiChallange

Projekt: Ski-Abfahrtsspiel auf echten Geländedaten. Spieltitel: **Schussfahrt**
(Repo-/Projektname: SkiChallange). Erste Strecke: Streif, Kitzbühel.

**Nach jeder Kontext-Komprimierung zuerst `PROGRESS.md` lesen.**
Spec: `DESIGN.md`. Recherche: `docs/streif-research.md`, `docs/data-sources.md`.

## Rechtliches (hart)
- Keine Grafiken, Sounds, Modelle, Streckendaten, Logos aus dem Original-Spiel
  (Greentube Ski Challenge). Keine Sponsor-/Event-Marken (kein "Hahnenkammrennen"-Logo,
  keine FIS-/Sponsorlogos). Ortsnamen (Streif, Mausefalle …) sind ok.
- `reference/` ist gitignored und nur visuelle Vorlage. Nie daraus laden, kopieren oder nachzeichnen.
- Nur offene Daten und CC0-Assets. Jede neue Quelle sofort in `CREDITS.md` **und**
  `game/data/credits.json` (wird im Spiel angezeigt) eintragen.

## Layout
- `game/` – Godot-4-Projekt (res://). Szenen `scenes/`, Code `scripts/<bereich>/`,
  Tests `tests/unit/`, Streckendaten `data/streif/`, Assets `assets/`.
- `tools/pipeline/` – Python-Datenpipeline (venv `tools/.venv`, gitignored).
- `data/raw/` – Rohdownloads (gitignored). Pipeline schreibt Ergebnisse nach `game/data/`.
- `docs/` – Recherche, Validierung, Screenshots.

## Befehle
```bash
# Godot 4.7.2 liegt in ~/.local/bin/godot
cd game && godot --headless --import                        # Import / Klassen-Cache
cd game && godot --headless -s addons/gut/gut_cmdln.gd      # alle GUT-Tests
cd game && godot --headless --quit-after 60 2>&1 | tee /tmp/smoke.log; ! grep -E "ERROR|WARNING" /tmp/smoke.log   # Start-Smoketest
cd game && godot                                            # Spiel starten
# Python-Pipeline
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
tools/.venv/bin/python tools/pipeline/run_all.py            # komplette Datenpipeline
```

## Code-Regeln
- GDScript mit statischen Typen überall (`var x: float`, `-> void`). Keine untypisierten Arrays,
  wo es vermeidbar ist (`Array[Vector3]`).
- Physik-/Spiellogik in reinen Klassen (`RefCounted`/`Resource`) ohne Szenenabhängigkeit,
  damit GUT sie headless testen kann. Nodes sind dünne Adapter.
- Alle Handling-Werte nur in `SkiTuning` (`res://resources/ski_tuning.tres`), keine Magic Numbers
  in der Physik.
- Einheiten: 1 Godot-Einheit = 1 m, Y oben, +X = Osten, −Z = Norden. Geschwindigkeiten intern m/s.
- Pipeline-Skripte sind reproduzierbar (feste URLs/BBox in `tools/pipeline/config.py`),
  idempotent und laden nur, was fehlt.
- Große Binärdateien (EXR, R16, PNG, GLB, OGG …) über Git LFS (siehe `.gitattributes`).

## Workflow
- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:` …), Commit nach jedem
  sinnvollen Schritt, Push am Phasenende.
- Phasenende: Tests grün, Projekt startet fehlerfrei, Screenshots geprüft, Review-Sub-Agent,
  `PROGRESS.md` aktualisieren.
- Entscheidungen kommen in `PROGRESS.md` unter "Entscheidungen".
- Sub-Agents nur für Recherche, Asset-Suche/Lizenzprüfung und Review; nie zwei an denselben Dateien.
