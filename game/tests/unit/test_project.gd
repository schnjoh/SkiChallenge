extends GutTest
## Smoke tests for the project scaffold.


func test_game_title_is_own_title() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Schussfahrt")


func test_main_scene_loads() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(scene)
	var inst: Node = scene.instantiate()
	assert_not_null(inst)
	inst.free()
