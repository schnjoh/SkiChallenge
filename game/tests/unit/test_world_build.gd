extends GutTest
## Builds the full Streif world headless (Terrain3D, trees, rings) and checks the result.

var world: World


func before_all() -> void:
	world = World.new()
	world.build_on_ready = false
	add_child(world)
	world.build()


func after_all() -> void:
	world.free()


func test_terrain_regions_cover_core() -> void:
	assert_not_null(world.terrain)
	assert_eq(world.terrain.get_region_size(), 1024)
	assert_eq(world.terrain.data.get_region_count(), 9)


func test_terrain_matches_height_field() -> void:
	# Terrain3D samples (vertices) must equal the physics height field exactly.
	var hf: HeightField = world.track.height_field
	for p: Vector2i in [Vector2i(1022, -542), Vector2i(10, -3000), Vector2i(3000, -10), Vector2i(1500, -1500)]:
		var pos: Vector3 = Vector3(p.x, 0.0, p.y)
		assert_almost_eq(world.terrain.data.get_height(pos), hf.height_at(p.x, p.y), 0.01)


func test_trees_placed() -> void:
	assert_gt(world.tree_count, 90000)


func test_rings_built() -> void:
	assert_not_null(world.get_node_or_null("Ring_far"))
	assert_not_null(world.get_node_or_null("Ring_horizon"))
	assert_gt(world.get_node("Ring_far").get_child_count(), 10)
