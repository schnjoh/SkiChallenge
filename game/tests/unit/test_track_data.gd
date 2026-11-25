extends GutTest
## Integration test against the real Streif data from the pipeline.

var td: TrackData


func before_all() -> void:
	td = TrackData.load_track()


func test_loads() -> void:
	assert_not_null(td)
	assert_not_null(td.height_field)
	assert_eq(td.height_field.width, 3072)
	assert_gt(td.line_points.size(), 1000)


func test_world_mapping_of_known_start_point() -> void:
	# First OSM node EPSG:31255 (-72570, 254617) -> x = E - E0, z = -(N - N0)
	var e0: float = float(td.meta["origin_e0"])
	var n0: float = float(td.meta["origin_n0"])
	var expected: Vector2 = Vector2(-72570.0 - e0, -(254617.0 - n0))
	var start: Vector3 = td.start_point()
	assert_almost_eq(Vector2(start.x, start.z).distance_to(expected), 0.0, 5.0)
	assert_almost_eq(td.height_field.height_at(start.x, start.z), 1663.0, 15.0)
	assert_almost_eq(start.y, td.height_field.height_at(start.x, start.z), 1.0)


func test_finish_and_drop_match_research() -> void:
	assert_almost_eq(td.finish_point().y, 805.0, 10.0)
	assert_almost_eq(td.start_point().y - td.finish_point().y, 860.0, 25.0)
	assert_almost_eq(td.length(), 3060.0, 100.0)


func test_line_lies_on_terrain() -> void:
	var worst: float = 0.0
	for i in range(0, td.line_points.size(), 25):
		var p: Vector3 = td.line_points[i]
		worst = maxf(worst, absf(p.y - td.height_field.height_at(p.x, p.z)))
	assert_lt(worst, 1.0)


func test_project_and_point_at_roundtrip() -> void:
	for s: float in [10.0, 512.0, 1600.0, 2950.0]:
		var p: Vector3 = td.point_at(s)
		assert_almost_eq(td.project(p), s, 0.5)
		assert_almost_eq(td.project(p + Vector3(0.0, 0.0, 0.0), s), s, 0.5)


func test_sections_in_order() -> void:
	assert_eq(td.section_at(0.0), "Start")
	assert_eq(td.section_at(td.section_s("Mausefalle") + 1.0), "Mausefalle")
	assert_gt(td.section_s("Zielsprung"), td.section_s("Hausbergkante"))
