class_name TrackValidation
extends RefCounted
## Checks a BotRun against the research targets (docs/streif-research.md, DESIGN §2/§4.7).

const OFFICIAL_LENGTH_M: float = 3312.0
const WIN_TIME_MIN_S: float = 110.0  ## 1:50
const WIN_TIME_MAX_S: float = 120.0  ## 2:00
const AVG_KMH: Vector2 = Vector2(101.0, 107.0)
const VMAX_KMH: float = 153.0
const GMAX: float = 3.8
const T100_S: Vector2 = Vector2(7.0, 10.0)  ## 100 km/h after ~8.5 s
const JUMP_LEN: Vector2 = Vector2(40.0, 65.0)  ## Mausefalle, Zielsprung (design: game 50-60 m)
const JUMP_LEN_SMALL: Vector2 = Vector2(15.0, 45.0)  ## Seidlalm, Hausbergkante (estimate 20-40 m)
const SECTION_TOLERANCE: float = 0.15
## Research §6 section speeds (km/h), compared with the bot's section average +-15 %.
const SECTION_KMH: Dictionary = {
	"Mausefalle": Vector2(105, 120), "Karussell": Vector2(60, 80), "Steilhang": Vector2(90, 100),
	"Brückenschuss": Vector2(90, 110), "Gschöss": Vector2(90, 110), "Alte Schneise": Vector2(110, 125),
	"Seidlalmsprung": Vector2(80, 90), "Lärchenschuss": Vector2(100, 110), "Oberhausberg": Vector2(60, 80),
	"Hausbergkante": Vector2(90, 105), "Traverse": Vector2(90, 105), "Zielsprung": Vector2(120, 145),
}
const BEGIN: String = "<!-- BOT-VALIDATION:BEGIN -->"
const END: String = "<!-- BOT-VALIDATION:END -->"

var track: TrackData
var run_a: BotRun
var run_b: BotRun
var checks: Array[Dictionary] = []  ## {name, ok, value, target, hard}
var scale: float = 1.0


func _init(p_track: TrackData, a: BotRun, b: BotRun = null) -> void:
	track = p_track
	run_a = a
	run_b = b
	scale = float(track.stats.get("length_3d_m", OFFICIAL_LENGTH_M)) / OFFICIAL_LENGTH_M


func _check(n: String, ok: bool, value: String, target: String, hard: bool = true) -> void:
	checks.append({"name": n, "ok": ok, "value": value, "target": target, "hard": hard})


func evaluate() -> void:
	var r: BotRun = run_a
	checks.clear()
	_check("Ziel erreicht, kein Sturz", r.finished and r.crash_reason.is_empty(),
			"ja" if r.finished else ("Sturz: " + r.crash_reason if r.crash_reason != "" else "DSQ: " + r.dsq_reason), "ja")
	_check("Alle Tore", r.gates_passed == r.gates.gates.size() and r.dsq_reason.is_empty(),
			"%d/%d" % [r.gates_passed, r.gates.gates.size()], "alle")
	var tmin: float = WIN_TIME_MIN_S * scale
	var tmax: float = WIN_TIME_MAX_S * scale
	_check("Zeit", r.finished and r.time >= tmin and r.time <= tmax, RaceTimer.format_time(r.time),
			"%s–%s (1:50–2:00 × %.3f)" % [RaceTimer.format_time(tmin), RaceTimer.format_time(tmax), scale])
	var avg: float = float(track.stats.get("length_3d_m", track.length())) / r.time * 3.6 if r.time > 0.0 else 0.0
	_check("Ø-Tempo (3D-Länge)", avg >= AVG_KMH.x * 0.97 and avg <= AVG_KMH.y * 1.03, "%.1f km/h" % avg,
			"101–107 km/h (±3 %)")
	_check("Netz-/Baumkontakte", r.net_contacts == 0, "%d" % r.net_contacts, "0")
	_check("Höchsttempo", r.vmax_kmh <= VMAX_KMH, "%.1f km/h" % r.vmax_kmh, "≤ 153 km/h")
	_check("Spitzen-g (Boden)", r.gmax <= GMAX, "%.2f g bei s=%.0f" % [r.gmax, r.gmax_s], "≤ 3,8 g")
	_check("100 km/h nach dem Start", r.t_100kmh >= T100_S.x and r.t_100kmh <= T100_S.y,
			"%.1f s (s=%.0f m)" % [r.t_100kmh, r.s_100kmh], "≈ 8,5 s")
	for j: Dictionary in track.jumps:
		var jr: Dictionary = r.jump_near(float(j["s_lip"]))
		var big: bool = float(j["length_m"]) >= 40.0
		var rng: Vector2 = JUMP_LEN if big else JUMP_LEN_SMALL
		var len_m: float = float(jr.get("length", 0.0))
		_check("Sprung %s" % j["name"], not jr.is_empty() and len_m >= rng.x and len_m <= rng.y,
				"%.0f m bei %.0f km/h, Landung %.1f m" % [len_m, float(jr.get("v0_kmh", 0.0)), float(jr.get("drop", 0.0))]
				if not jr.is_empty() else "kein Flug", "%.0f–%.0f m" % [rng.x, rng.y], big)
	for sec: Dictionary in r.sections:
		var n: String = sec["name"]
		if not SECTION_KMH.has(n):
			continue
		var rng: Vector2 = SECTION_KMH[n]
		var avg_s: float = sec["avg_kmh"]
		_check("Tempo %s" % n, avg_s >= rng.x * (1.0 - SECTION_TOLERANCE) and avg_s <= rng.y * (1.0 + SECTION_TOLERANCE),
				"Ø %.0f (%.0f–%.0f) km/h" % [avg_s, sec["min_kmh"], sec["max_kmh"]], "%.0f–%.0f km/h ±15 %%" % [rng.x, rng.y], false)
	if run_b != null:
		_check("Determinismus (2 Läufe)", is_equal_approx(run_a.time, run_b.time) and run_a.final_pos.is_equal_approx(run_b.final_pos),
				"%.4f / %.4f s" % [run_a.time, run_b.time], "identisch")


## Hard checks only; section speeds are reported as soft targets.
func passed() -> bool:
	for c: Dictionary in checks:
		if c["hard"] and not c["ok"]:
			return false
	return true


func report_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for c: Dictionary in checks:
		lines.append("%s %-28s %s  (Ziel %s)" % ["ok  " if c["ok"] else ("FAIL" if c["hard"] else "warn"), c["name"], c["value"], c["target"]])
	lines.append("VALIDATION " + ("PASSED" if passed() else "FAILED"))
	return "\n".join(lines)


func markdown() -> String:
	var r: BotRun = run_a
	var md: PackedStringArray = PackedStringArray()
	md.append(BEGIN)
	md.append("_Automatisch erzeugt von `game/scripts/tools/validate_track.gd` am %s._" % Time.get_date_string_from_system())
	md.append("")
	md.append("**Ergebnis: %s** — Zeit %s, %d Tore, %d Zwischenzeiten." % ["bestanden" if passed() else "NICHT bestanden",
			RaceTimer.format_time(r.time), r.gates.gates.size(), r.gates.splits.size()])
	md.append("")
	md.append("| Prüfung | Bot | Ziel | |")
	md.append("|---|---|---|---|")
	for c: Dictionary in checks:
		md.append("| %s | %s | %s | %s |" % [c["name"], c["value"], c["target"], "✅" if c["ok"] else ("❌" if c["hard"] else "⚠️")])
	md.append("")
	md.append("Zwischenzeiten: " + ", ".join(Array(r.split_times).map(func(t: float) -> String: return RaceTimer.format_time(t))))
	md.append("")
	md.append("| Abschnitt | s | Zeit | Ø km/h | min | max |")
	md.append("|---|---|---|---|---|---|")
	for sec: Dictionary in r.sections:
		md.append("| %s | %.0f–%.0f | %.2f s | %.0f | %.0f | %.0f |" % [sec["name"], sec["s0"], sec["s1"], sec["t"],
				sec["avg_kmh"], sec["min_kmh"], sec["max_kmh"]])
	md.append("")
	md.append("Flugphasen > 15 m: " + ", ".join(r.jumps.filter(func(j: Dictionary) -> bool: return float(j["length"]) > 15.0)
			.map(func(j: Dictionary) -> String: return "s=%.0f %.0f m (%.0f km/h, Landung %.1f m)" % [j["s0"], j["length"], j["v0_kmh"], j["drop"]])))
	md.append(END)
	return "\n".join(md)


## Replaces the generated block in docs/validation.md (appends a section if missing).
func write_markdown(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var block: String = markdown()
	var a: int = text.find(BEGIN)
	var b: int = text.find(END)
	if a >= 0 and b > a:
		text = text.substr(0, a) + block + text.substr(b + END.length())
	else:
		text += "\n## 4. Validierungs-Bot (Phase 4)\n\n" + block + "\n"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
