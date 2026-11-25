# PROGRESS.md

## Stand (2026-11-25)
- Phase 0–4: **abgeschlossen** (Reviews Phase 2+3, 4 und 5/6 umgesetzt).
- Phase 5 – Spielablauf: **abgeschlossen** (Menü, Rennen/Training, HUD, Ghost, Bestenliste, Wiederholung,
  Pause, prozedurale Sounds, Grafikeinstellungen, Credits-Screen).
- Phase 6 – Feinschliff: **abgeschlossen** bis auf das 60-fps-Ziel auf „mittel“ (siehe Offene Punkte);
  Schnee-Glitzern, Skispuren, Zuschauer, Performance gemessen, Export Linux + Windows funktioniert.
- **Definition of Done erfüllt**: Streif spielbar Start→Ziel mit Zeitmessung, Ghost, Bestenliste; F1-Menü;
  Validierungs-Bot bestanden; README erklärt Setup, Steuerung, Datenpipeline.

## Exakt nächster Schritt (optional, nach DoD)
1. Performance „mittel“ auf stabile 60 fps: schlanker eigener Terrain-Shader oder Terrain3D-Material vereinfachen,
   Baum-Impostoren, statische Geländeschatten (`docs/validation.md` §3).
2. Bot schneller in Kurven (Zeit 1:54,3 liegt im Fenster, Abschnitte Steilhang/Hausbergkante eher langsam).

## Erledigt
- Phase 0: Godot 4.7.2 + git-lfs nach ~/.local ohne sudo; venv mit rasterio (GDAL 3.12);
  Godot-Projekt `game/` mit GUT 9.7.1 + Terrain3D 1.1.0; Recherche, DESIGN, CLAUDE, CREDITS, README.
- Phase 1 (`tools/pipeline/`, Einstieg `run_all.py`): OSM-Linie, DGM/DOM 50 cm, Kern 3072² @ 1 m, Fern-/Horizontring,
  Control-Map, Farbkarte, 98 068 Bäume, 1652 Gebäude; `check_outputs` (jetzt 28 Prüfungen).
- Phase 2: `HeightField`, `TrackData`, `World` (Terrain3D, CC0-Texturen, Bäume über Instancer, Fern-/Horizontring,
  Sky-Shader), Screenshot-Tour + fps (`docs/validation.md` §2/§3).
- Phase 3: `SkiPhysics` (rein, 120 Hz, deterministisch), `SkiTuning` (alle Werte, F1-Menü mit Reglern,
  Presets JSON `resources/presets/*.json` + `user://presets/`), `Rider` (Interpolation), `RiderVisual` (Posen per Code,
  Geister-Variante), `ChaseCamera` (Verfolger/Helm, FOV nach Tempo, Wackeln), Steuerung Tastatur+Gamepad.
- Phase 4:
  - `process_shaping.py` + `jumps.json`: präparierte Piste im Korridor (geglättetes Längsprofil, quadratisches
    Querprofil), gebaute Sprünge Mausefalle/Seidlalm/Hausbergkante/Zielsprung (Kante, Knoll, Landehang, Auslauf ≤ 3 g),
    Projektion über interpolierte Normalen (stetiges s), Glättung an Faltstellen enger Kurven.
  - `RacingLine` (min. Krümmung im Korridor) → `racing_line.json`; `GateSet` → `gates.json` (41 Tore, 5 Zwischenzeiten);
    `RaceTimer` (Torfolge, DSQ bei s > Tor + 25 m, interpolierte Zeiten); `CourseBarriers` (A/B-Netze, Bäume);
    `CourseBuilder` (Netz-Shader, Tore, Starthaus, Zielbogen ohne Marken); F2-Editor (`TrackEditor`).
  - Validierungs-Bot `BotRun`/`TrackValidation` (`scripts/tools/validate_track.gd`, GUT-Test): alle Kriterien grün.
- Phase 5: `main_menu.gd` (Menü über dem Live-Gelände), `Session` (Einstellungen `user://settings.json`), `Hud`,
  `PauseMenu`, `Ghost` (60 Hz, binär), `Leaderboard` (Top 10), Wiederholung, `RideAudio` (Wind/Kante/Publikum/Jubel).
- Phase 6: Schnee-Glitzern (Injektion in den generierten Terrain3D-Shader), `SkiTrail`, `Spectators` (MultiMesh,
  Jubel im Vertex-Shader), Qualitätsstufen, `perf_run.tscn`, `export_presets.cfg` (Linux/Windows, `data/*` +
  Presets eingeschlossen, GUT/Tests/Tools ausgeschlossen); exportierter Linux-Build startet und lädt die Strecke.

## Build / Lint / Tests
- Godot-Import fehlerfrei, GUT 49/49 grün, Smoketest 0 Fehler/Warnungen, Ruff sauber, `check_outputs` PASSED,
  Validierung PASSED (1:54,34, Ø 101,4 km/h, max 152,8 km/h, 3,60 g, Mausefalle 45 m, Zielsprung 53 m).
- Export: `godot --headless --export-release "Linux"|"Windows"` → `export/` (gitignored). Beim Export meldet das
  Terrain3D-Export-Plugin headless einen harmlosen Skriptfehler (`get_version` auf Nil, erwartet ein Editor-Terrain).

## Offene Bugs / Auffälligkeiten
- **Performance**: „mittel“ Ø 60–74 fps, 1 %-Low ~40–45 auf Iris Xe (Ziel stabile 60 nicht ganz erreicht);
  „niedrig“ Ø 101 / 1 %-Low 58. Messungen thermisch ±15 %.
- Mehr Kurventempo lässt den Bot Tore verpassen (Pure Pursuit); Abschnitte Steilhang/Hausbergkante eher langsam,
  Oberhausberg zu schnell (weiche Prüfung, ⚠️).
- Ghost-Zwischenzeiten werden per Index verglichen; nach Änderung der Splits in `gates.json` den Ghost löschen.
- `standard.json` muss bei geänderten `SkiTuning`-Defaults neu geschrieben werden (zuletzt 2026-11-25).
- Pistenbreiten in `config.SECTION_WIDTHS_M` geschätzt. Multipolygon-Gebäude fehlen in `buildings.json`.
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
- **Piste als präparierte Fläche** statt reiner Offsets: Naturkanten liegen schräg zur Linie und schleuderten den
  Fahrer neben der Mittellinie ab; im Korridor wird Profil(s) + Querprofil(d) neu aufgebaut, am Rand eingeblendet.
- Sprungweiten wie beim Skispringen als 3D-Distanz Absprung→Landung gemessen.
- Sprünge werden in der Pipeline gebacken (Python), Godot liest nur `height.r32` → Render = Physik.
- Hocke-cdA 0,22 m² (statt 0,16): Spitze sonst > 153 km/h; Literatur 0,15–0,25 m².
- Skier richten sich in der Luft zur Flugbahn aus (`air_align_rate`), sonst Stürze nach jeder Bodenwelle in Kurven.
- Abhebe-Hysterese in Sekunden (`liftoff_time`) statt Schritten (unabhängig von der Schrittweite).
- Tore 14 m breit, zentriert auf der Rennlinie, dichter in Kurven; Zwischenzeiten über Mittellinien-s.
- Sounds **prozedural synthetisiert** (eigene Erzeugung, keine Fremd-Assets/Lizenzen): Wind, Kante, Publikum, Jubel.
- Ghost-Datei binär (`user://ghosts/streif.ghost`, 60 Hz), Bestenliste `user://leaderboard.json` (Top 10).
- Editierte Tore/Rennlinie: im Entwicklungs-Checkout direkt in `data/streif/`, im Export nach `user://tracks/streif/`.
- Headless läuft ohne Audio (Dummy-Treiber würde Playback-Objekte beim Beenden lecken).
- μ_Gleit 0,022 (gewachste Rennski) statt 0,03: Ø-Tempo-Prüfung strikt 101–107 km/h ohne Toleranz.
- Bot springt 0,3 s vor den Kanten aus `jumps.json` vor (DESIGN §4.7).
- Standard-Grafik = „mittel“; Schattenqualität „mittel“ ohne Gelände-/Baumschatten, 1 Kaskade, Atlas 2048.
- Bot-/Demo-Läufe (`Game.enable_bot`, Perf-Messung) schreiben nie in Bestenliste/Ghost (`record_results`);
  gewertet wird nur mit Standard-Handling (F1-Änderungen = „nicht gewertet“). Bei der Messung entstandene
  Bot-Einträge in `user://` wurden entfernt (Review Phase 5/6).
- Replay am Gamepad auf R3 (Guide wird oft vom System abgefangen).
- Exportvorlagen offiziell von GitHub (nur Linux/Windows x86_64 entpackt nach `~/.local/share/godot/export_templates`).
