extends GutTest
## Verifies the Terrain3D GDExtension loads (also headless).


func test_terrain3d_class_exists() -> void:
	assert_true(ClassDB.class_exists("Terrain3D"), "Terrain3D GDExtension not loaded")


func test_terrain3d_can_be_instantiated() -> void:
	var t: Node = ClassDB.instantiate("Terrain3D")
	assert_not_null(t)
	if t:
		t.free()
