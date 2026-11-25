extends Node
## Dev tool: instantiates SHOT_SCENE, optionally calls SHOT_CALL(SHOT_ARG), waits SHOT_DELAY s,
## saves SHOT_OUT (png). Needs a display (use --display-driver x11).


func _ready() -> void:
	var scene: Node = (load(OS.get_environment("SHOT_SCENE")) as PackedScene).instantiate()
	add_child(scene)
	if OS.has_environment("SHOT_CALL"):
		scene.call(OS.get_environment("SHOT_CALL"), OS.get_environment("SHOT_ARG"))
	await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY"))).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	get_tree().quit()
