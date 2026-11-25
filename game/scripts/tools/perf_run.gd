extends Node
## Performance run: the game with the bot driving the whole course in real time, VSync off.
## Settings preset via PERF_PRESET=medium|high|low. Writes frame-time stats to stdout and
## docs/img/perf_<preset>.txt. Run: godot --path game --display-driver x11 --resolution 1920x1080
##   res://scenes/tools/perf_run.tscn

const PRESETS: Dictionary = {
	"low": {"render_scale": 0.67, "fsr": true, "view_distance": 0.5, "tree_density": 0.3, "shadows": 0, "msaa": 0},
	"medium": {"render_scale": 0.8, "fsr": true, "view_distance": 0.7, "tree_density": 0.5, "shadows": 1, "msaa": 0},
	"high": {"render_scale": 1.0, "fsr": false, "view_distance": 1.0, "tree_density": 1.0, "shadows": 2, "msaa": 1},
}

var game: Game
var frames: PackedFloat32Array = PackedFloat32Array()
var preset: String
var sections: Dictionary = {}  ## section -> PackedFloat32Array of frame times
var gpu_ms: float = 0.0
var cpu_render_ms: float = 0.0
var process_ms: float = 0.0
var physics_ms: float = 0.0
var n_meas: int = 0


func _ready() -> void:
	preset = OS.get_environment("PERF_PRESET") if OS.has_environment("PERF_PRESET") else "medium"
	var saved: Dictionary = Session.settings.duplicate()
	for k: String in PRESETS[preset]:
		Session.set_setting(k, PRESETS[preset][k])
	for kv: String in OS.get_environment("PERF_OVERRIDE").split(",", false):
		var kvp: PackedStringArray = kv.split("=")
		Session.set_setting(kvp[0], Session.typeof_like(Session.DEFAULTS[kvp[0]], kvp[1]))
	Session.set_setting("vsync", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Session.mode = Session.Mode.RACE
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	game.enable_bot()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	Session.settings = saved  # never persist the perf preset


func _process(dt: float) -> void:
	if game.state == Game.State.RUNNING and game.timer.is_running():
		frames.append(dt * 1000.0)
		var vp: RID = get_viewport().get_viewport_rid()
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu_render_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n_meas += 1
		var sec: String = game.world.track.section_at(game.timer.s_now)
		var arr: PackedFloat32Array = sections.get(sec, PackedFloat32Array())
		arr.append(dt * 1000.0)
		sections[sec] = arr  # packed arrays are values: store back
	var stop_s: float = float(OS.get_environment("PERF_STOP_S")) if OS.has_environment("PERF_STOP_S") else 1e9
	if game.state == Game.State.DONE or game.timer.s_now > stop_s or (frames.size() > 0 and game.rider.physics.time > 200.0):
		_report()
		get_tree().quit()


static func stats(a: PackedFloat32Array) -> Dictionary:
	var s: Array = Array(a)
	s.sort()
	var sum: float = 0.0
	for v: float in s:
		sum += v
	var avg: float = sum / maxf(1.0, float(s.size()))
	var p99: float = s[int(s.size() * 0.99)] if s.size() > 0 else 0.0
	return {"fps": 1000.0 / avg, "ms": avg, "p99_ms": p99, "low1_fps": 1000.0 / maxf(p99, 0.001)}


func _report() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var vs: Vector2i = get_viewport().get_visible_rect().size
	var st: Dictionary = stats(frames)
	lines.append("preset=%s resolution=%dx%d renderer=%s gpu=%s" % [preset, vs.x, vs.y,
			RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	lines.append("total: %.1f fps avg, %.1f ms avg, p99 %.1f ms (1%% low %.1f fps), %d frames, race %s" % [st["fps"],
			st["ms"], st["p99_ms"], st["low1_fps"], frames.size(), RaceTimer.format_time(game.timer.race_time)])
	var n: float = maxf(1.0, float(n_meas))
	lines.append("avg per frame: gpu %.1f ms, render cpu %.1f ms, process %.1f ms, physics %.1f ms" % [gpu_ms / n,
			cpu_render_ms / n, process_ms / n, physics_ms / n])
	for sec: String in sections:
		var ss: Dictionary = stats(sections[sec])
		lines.append("  %-14s %.1f fps (1%% low %.1f)" % [sec, ss["fps"], ss["low1_fps"]])
	var text: String = "\n".join(lines)
	print(text)
	var out: String = ProjectSettings.globalize_path("res://").path_join("../docs/img/perf_%s.txt" % preset)
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if f:
		f.store_string(text + "\n")
