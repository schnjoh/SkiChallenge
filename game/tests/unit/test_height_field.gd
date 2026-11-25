extends GutTest
## HeightField: triangle interpolation (Terrain3D diagonal), normals, edges.


func _grid(values: Array[float], w: int, d: int) -> HeightField:
	return HeightField.from_array(PackedFloat32Array(values), w, d, 1.0, 0.0, 0.0)


func test_vertices_are_exact() -> void:
	var hf: HeightField = _grid([0.0, 1.0, 2.0, 3.0], 2, 2)
	assert_almost_eq(hf.height_at(0.0, 0.0), 0.0, 1e-6)
	assert_almost_eq(hf.height_at(1.0, 0.0), 1.0, 1e-6)
	assert_almost_eq(hf.height_at(0.0, 1.0), 2.0, 1e-6)
	assert_almost_eq(hf.height_at(1.0, 1.0), 3.0, 1e-6)


func test_plane_is_reproduced_exactly() -> void:
	# h = 2x - 3z + 5 on a 4x4 grid with 0.5 m spacing, offset origin
	var vals: Array[float] = []
	for r in 4:
		for c in 4:
			vals.append(2.0 * (10.0 + c * 0.5) - 3.0 * (-20.0 + r * 0.5) + 5.0)
	var hf: HeightField = HeightField.from_array(PackedFloat32Array(vals), 4, 4, 0.5, 10.0, -20.0)
	for p: Vector2 in [Vector2(10.3, -19.9), Vector2(11.2, -18.6), Vector2(10.9, -19.1)]:
		assert_almost_eq(hf.height_at(p.x, p.y), 2.0 * p.x - 3.0 * p.y + 5.0, 1e-4)
		var n: Vector3 = hf.normal_at(p.x, p.y)
		var expected: Vector3 = Vector3(-2.0, 1.0, 3.0).normalized()
		assert_almost_eq(n.distance_to(expected), 0.0, 1e-4)


func test_diagonal_matches_terrain3d_split() -> void:
	# Only h11 raised: on diagonal (0,0)-(1,1) the surface is piecewise linear along it.
	var hf: HeightField = _grid([0.0, 0.0, 0.0, 4.0], 2, 2)
	assert_almost_eq(hf.height_at(0.5, 0.5), 2.0, 1e-6)   # on the diagonal: half of h11
	assert_almost_eq(hf.height_at(0.75, 0.25), 1.0, 1e-6) # upper triangle: h = 4 * fv
	assert_almost_eq(hf.height_at(0.25, 0.75), 1.0, 1e-6) # lower triangle: h = 4 * fu


func test_outside_is_clamped() -> void:
	var hf: HeightField = _grid([1.0, 2.0, 3.0, 4.0], 2, 2)
	assert_almost_eq(hf.height_at(-5.0, -5.0), 1.0, 1e-6)
	assert_almost_eq(hf.height_at(9.0, 9.0), 4.0, 1e-6)
	assert_false(hf.contains(-0.1, 0.5))
	assert_true(hf.contains(0.5, 0.5))
