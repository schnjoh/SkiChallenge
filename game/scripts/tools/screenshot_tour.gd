extends Node3D
## Renders fixed camera views along the track to docs/img/tour_*.png and prints FPS per view.
## Run: godot --path game --display-driver x11 res://scenes/tools/screenshot_tour.tscn
## (needs a display; under Wayland Godot pauses rendering while the window is hidden -> use x11)

const VIEWS: Array[Dictionary] = [
	{"name": "start", "section": "Start", "back": -8.0, "ahead": 60.0, "up": 6.0},
	{"name": "mausefalle", "section": "Mausefalle", "back": 40.0, "ahead": 60.0, "up": 8.0},
	{"name": "steilhang", "section": "Steilhang", "back": 40.0, "ahead": 80.0, "up": 8.0},
	{"name": "hausbergkante", "section": "Hausbergkante", "back": 40.0, "ahead": 80.0, "up": 8.0},
	{"name": "ziel", "section": "Zielsprung", "back": 60.0, "ahead": 120.0, "up": 10.0},
	{"name": "overview", "section": "Seidlalmsprung", "back": 900.0, "ahead": 300.0, "up": 650.0},
]
const SETTLE_FRAMES: int = 45
const MEASURE_FRAMES: int = 90

var world: World
var cam: Camera3D


func _ready() -> void:
	# measure raw frame time, not the compositor's refresh pacing
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	world = World.new()
	# perf experiments: TOUR_TREES=0..1, TOUR_SHADOWS=0/1, TOUR_RINGS=0/1, TOUR_TAG=suffix
	world.tree_density = float(OS.get_environment("TOUR_TREES")) if OS.has_environment("TOUR_TREES") else 1.0
	world.shadows = OS.get_environment("TOUR_SHADOWS") != "0"
	world.rings = OS.get_environment("TOUR_RINGS") != "0"
	add_child(world)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 20000.0
	cam.near = 0.3
	add_child(cam)
	cam.make_current()
	world.set_camera(cam)
	await _run()
	get_tree().quit()


func _run() -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://").path_join("../docs/img")
	var report: Array[String] = []
	for v: Dictionary in VIEWS:
		var s: float = world.track.section_s(str(v["section"]))
		var from: Vector3 = world.track.point_at(s - float(v["back"]))
		var to: Vector3 = world.track.point_at(s + float(v["ahead"]))
		from.y = world.track.height_field.height_at(from.x, from.z) + float(v["up"])
		cam.global_position = from
		cam.look_at(to + Vector3(0, 1.5, 0), Vector3.UP)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var t0: int = Time.get_ticks_usec()
		for i in MEASURE_FRAMES:
			await get_tree().process_frame
		var fps: float = MEASURE_FRAMES / ((Time.get_ticks_usec() - t0) / 1_000_000.0)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		if OS.get_environment("TOUR_TAG").is_empty():
			img.save_png(out_dir.path_join("tour_%s.png" % v["name"]))
		var line: String = "%s: s=%.0f fps=%.1f" % [v["name"], s, fps]
		report.append(line)
		print(line)
	var f: FileAccess = FileAccess.open(out_dir.path_join("tour_fps%s.txt" % OS.get_environment("TOUR_TAG")), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
