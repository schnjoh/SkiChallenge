extends Node
## Scratch/dev tool: runs the game scene with the bot for N seconds and saves screenshots.
## env: SHOT_TIMES="2,6,10" (s), SHOT_DIR, SHOT_HELMET=1, SHOT_F1=1

var game: Game
var times: PackedFloat32Array
var idx: int = 0
var out_dir: String


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for t: String in OS.get_environment("SHOT_TIMES").split(",", false):
		times.append(float(t))
	if times.is_empty():
		times = PackedFloat32Array([1.0, 5.0, 9.0])
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_cache_dir()
	if game.has_method("enable_bot"):
		game.call("enable_bot")
	if OS.get_environment("SHOT_HELMET") == "1":
		game.cam.toggle_mode()
	if OS.get_environment("SHOT_F1") == "1":
		game.tuning_menu.toggle()
	if OS.get_environment("SHOT_F2") == "1":
		game.track_editor.toggle()


func _process(_dt: float) -> void:
	if idx >= times.size():
		get_tree().quit()
		return
	if game.rider.physics.time >= times[idx]:
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var p: String = out_dir.path_join("shot_%02d.png" % idx)
		img.save_png(p)
		print("shot %s t=%.1f v=%.0f tuck=%.2f edge=%.1f" % [p, game.rider.physics.time, game.rider.physics.speed_kmh(), game.rider.physics.tuck_amount, game.rider.physics.edge_angle])
		idx += 1
