extends GutTest
## Ghost recording/serialisation, local leaderboard, net and tree collision.


func _flat() -> HeightField:
	return HeightField.from_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0]), 2, 2, 2000.0, -1000.0, -1000.0)


func test_ghost_record_interpolate_and_roundtrip() -> void:
	var phys: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _flat())
	phys.reset(Vector3.ZERO, 0.0, 10.0)
	var g: Ghost = Ghost.new()
	var t: float = 0.0
	while t < 2.0:
		g.record(t, phys)
		phys.step(SkiInput.make(0.0, true), 1.0 / 120.0)
		t += 1.0 / 120.0
	assert_almost_eq(float(g.size()), 120.0, 2.0, "60 Hz samples")
	g.final_time = 2.0
	g.splits = PackedFloat32Array([0.5, 1.5])
	var path: String = "user://test.ghost"
	assert_eq(g.save(path), OK)
	var back: Ghost = Ghost.load_file(path)
	assert_not_null(back)
	assert_eq(back.size(), g.size())
	assert_almost_eq(back.splits[1], 1.5, 1e-6)
	var proxy: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _flat())
	assert_true(back.apply_to(1.0, proxy))
	assert_almost_eq(proxy.pos.z, -10.0, 0.3, "10 m/s north after 1 s")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_ghost_rejects_garbage() -> void:
	var path: String = "user://garbage.ghost"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not a ghost file at all")
	f.close()
	assert_null(Ghost.load_file(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_leaderboard_sorted_and_capped() -> void:
	var path: String = "user://test_lb.json"
	var lb: Leaderboard = Leaderboard.load_file(path)
	assert_eq(lb.best_time("x"), -1.0)
	assert_eq(lb.add("x", "A", 115.0, PackedFloat32Array()), 1)
	assert_eq(lb.add("x", "B", 112.0, PackedFloat32Array()), 1)
	assert_eq(lb.add("x", "C", 120.0, PackedFloat32Array()), 3)
	for i in 10:
		lb.add("x", "Z", 200.0 + i, PackedFloat32Array())
	assert_eq(lb.entries("x").size(), Leaderboard.MAX_ENTRIES)
	assert_eq(lb.add("x", "slow", 999.0, PackedFloat32Array()), 0)
	assert_eq(lb.save(), OK)
	var back: Leaderboard = Leaderboard.load_file(path)
	assert_almost_eq(back.best_time("x"), 112.0, 1e-6)
	assert_eq(str((back.entries("x")[0] as Dictionary)["name"]), "B")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _net_barriers() -> CourseBarriers:
	var cb: CourseBarriers = CourseBarriers.new()
	cb.nets = [{"points": PackedVector2Array([Vector2(5, 100), Vector2(5, -100)]), "kind": "B", "side": 1.0}]
	cb._index_nets()
	return cb


func test_net_bounces_slow_glancing_contact() -> void:
	var cb: CourseBarriers = _net_barriers()
	var phys: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _flat())
	phys.reset(Vector3(4.8, 0, 0), 0.0, 0.0)
	phys.vel = Vector3(3.0, 0.0, -20.0)  # 11 km/h into the net, mostly along it
	var p0: Vector3 = Vector3(4.6, 0, 0)
	assert_eq(cb.resolve(phys, p0), "Netz")
	assert_false(phys.is_crashed())
	assert_lt(phys.vel.x, 0.0, "pushed back")
	assert_lt(phys.pos.x, 5.0)


func test_net_crash_when_fast_into_it() -> void:
	var cb: CourseBarriers = _net_barriers()
	var phys: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _flat())
	phys.reset(Vector3(5.2, 0, 0), 0.0, 0.0)
	phys.vel = Vector3(20.0, 0.0, -10.0)
	assert_eq(cb.resolve(phys, Vector3(4.8, 0, 0)), "Netz")
	assert_true(phys.is_crashed())


func test_real_track_nets() -> void:
	var track: TrackData = TrackData.load_track()
	var cb: CourseBarriers = CourseBarriers.build(track, false)
	assert_gt(cb.segment_count(), 1000)
	var kinds: Dictionary = {}
	for n: Dictionary in cb.nets:
		kinds[n["kind"]] = true
	assert_true(kinds.has("A") and kinds.has("B"), "A and B nets")
