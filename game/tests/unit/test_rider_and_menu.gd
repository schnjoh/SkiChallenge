extends GutTest
## Node adapters: rider visual poses, tuning menu sliders and presets.


func _flat() -> HeightField:
	return HeightField.from_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0]), 2, 2, 1000.0, -500.0, -500.0)


func test_rider_visual_poses() -> void:
	var phys: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _flat())
	phys.reset(Vector3.ZERO, 0.0)
	var v: RiderVisual = RiderVisual.new()
	add_child_autofree(v)
	v.apply_pose(phys, 1.0)
	var head_up: float = v.head_position().y
	phys.tuck_amount = 1.0
	v.apply_pose(phys, 1.0)
	assert_lt(v.head_position().y, head_up - 0.4, "tuck lowers the head")
	assert_gt(v.head_position().y, 0.3, "head stays above the skis")
	phys.phase = SkiPhysics.Phase.CRASHED
	v.apply_pose(phys, 0.1)
	assert_true(v.visible)


func test_tuning_menu_has_slider_per_value_and_edits_live() -> void:
	var t: SkiTuning = SkiTuning.new()
	var menu: TuningMenu = TuningMenu.new(t)
	add_child_autofree(menu)
	assert_eq(menu._rows.size(), t.tunable_properties().size())
	var s: HSlider = menu._rows["mu_glide"]["slider"]
	s.value = 0.05
	assert_almost_eq(t.mu_glide, 0.05, 1e-6)


func test_builtin_presets_load() -> void:
	var found: PackedStringArray = TuningMenu.list_presets()
	assert_gt(found.size(), 0, "at least one shipped preset")
	for p: String in found:
		if p.begins_with("res://"):
			var t: SkiTuning = SkiTuning.load_json(p)
			assert_gt(t.mass, 0.0, p)
