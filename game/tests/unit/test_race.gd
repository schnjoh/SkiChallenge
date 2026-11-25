extends GutTest
## Gates, timing, DSQ and the validation bot on the real track.

var _track: TrackData


func before_all() -> void:
	_track = TrackData.load_track()


func _straight_track() -> TrackData:
	# synthetic track: straight line north (-z), 1000 m, flat
	var td: TrackData = TrackData.new()
	for i in 501:
		td.line_points.append(Vector3(0.0, 0.0, -2.0 * i))
		td.line_s.append(2.0 * i)
	td.sections = [{"name": "Start", "s": 0.0, "width_m": 30.0}]
	return td


func _gates(td: TrackData, at: Array[float]) -> GateSet:
	var gs: GateSet = GateSet.new()
	for s: float in at:
		gs.gates.append({"left": Vector2(-6.0, -s), "right": Vector2(6.0, -s)})
	gs.splits = [{"name": "A", "s": 500.0}]
	gs.finish_s = 1000.0
	gs.finalize(td)
	return gs


## Drives along x = lateral at 20 m/s and returns the timer.
func _drive(td: TrackData, gs: GateSet, lateral: Callable) -> RaceTimer:
	var timer: RaceTimer = RaceTimer.new(td, gs)
	var dt: float = 1.0 / 120.0
	var t: float = 0.0
	var p: Vector3 = Vector3(lateral.call(0.0), 0.0, 0.0)
	while t < 60.0 and timer.state != RaceTimer.State.FINISHED and timer.state != RaceTimer.State.DSQ:
		var z: float = -(t + dt) * 20.0
		var p1: Vector3 = Vector3(lateral.call(-z), 0.0, z)
		timer.update(p, p1, t, t + dt)
		p = p1
		t += dt
	return timer


func test_segment_cross() -> void:
	assert_almost_eq(GateSet.segment_cross(Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)), 0.5, 1e-6)
	assert_eq(GateSet.segment_cross(Vector2(2, 1), Vector2(2, -1), Vector2(-1, 0), Vector2(1, 0)), -1.0)


func test_clean_run_times_interpolated() -> void:
	var td: TrackData = _straight_track()
	var gs: GateSet = _gates(td, [100.0, 300.0, 700.0])
	var timer: RaceTimer = _drive(td, gs, func(_s: float) -> float: return 0.0)
	assert_eq(timer.state, RaceTimer.State.FINISHED)
	assert_eq(timer.next_gate, 3)
	# start at s=2 m, finish at 1000 m with 20 m/s -> 49.9 s, split at 500 m -> 24.9 s
	assert_almost_eq(timer.finish_time, 49.9, 1e-3)
	assert_almost_eq(timer.split_times[0], 24.9, 1e-3)


func test_missed_gate_disqualifies() -> void:
	var td: TrackData = _straight_track()
	var gs: GateSet = _gates(td, [100.0, 300.0])
	# passes gate 1, then runs 10 m to the side of gate 2
	var timer: RaceTimer = _drive(td, gs, func(s: float) -> float: return 0.0 if s < 200.0 else 10.0)
	assert_eq(timer.state, RaceTimer.State.DSQ)
	assert_string_contains(timer.dsq_reason, "Tor 2")


func test_format_time() -> void:
	assert_eq(RaceTimer.format_time(115.286), "1:55.29")
	assert_eq(RaceTimer.format_delta(-0.5), "-0.50")


func test_gates_json_roundtrip() -> void:
	var gs: GateSet = GateSet.for_track(_track)
	assert_gt(gs.gates.size(), 20)
	var path: String = "user://test_gates.json"
	assert_eq(gs.save(path), OK)
	var back: GateSet = GateSet.load_file(path, _track)
	assert_eq(back.gates.size(), gs.gates.size())
	assert_true((back.gates[5]["left"] as Vector2).is_equal_approx(gs.gates[5]["left"]))
	assert_eq(back.splits.size(), 5)
	for g: Dictionary in gs.gates:
		var w: float = (g["left"] as Vector2).distance_to(g["right"])
		assert_true(w >= GateSet.MIN_WIDTH - 1e-3, "gate %d width %.1f" % [g["id"], w])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_validation_bot_passes() -> void:
	var tuning: SkiTuning = (load("res://resources/ski_tuning.tres") as SkiTuning).duplicate()
	var a: BotRun = BotRun.new(_track, tuning).run()
	var b: BotRun = BotRun.new(_track, tuning).run()
	var v: TrackValidation = TrackValidation.new(_track, a, b)
	v.evaluate()
	assert_true(v.passed(), v.report_text())


func test_training_start_mid_course_no_dsq() -> void:
	var td: TrackData = _straight_track()
	var gs: GateSet = _gates(td, [100.0, 300.0, 700.0])
	var timer: RaceTimer = RaceTimer.new(td, gs)
	timer.start_at(400.0, 0.0)
	assert_eq(timer.next_gate, 2, "gates before the restart point are skipped")
	assert_eq(timer.split_times.size(), 0, "split at 500 m still ahead")
	var t: float = 0.0
	var p: Vector3 = Vector3(0, 0, -400)
	while t < 40.0 and timer.state == RaceTimer.State.RUNNING:
		var p1: Vector3 = p + Vector3(0, 0, -20.0 / 120.0)
		timer.update(p, p1, t, t + 1.0 / 120.0)
		p = p1
		t += 1.0 / 120.0
	assert_eq(timer.state, RaceTimer.State.FINISHED, timer.dsq_reason)
	assert_almost_eq(timer.finish_time, 30.0, 0.02)


func test_abort_stops_timing() -> void:
	var td: TrackData = _straight_track()
	var gs: GateSet = _gates(td, [100.0])
	var timer: RaceTimer = RaceTimer.new(td, gs)
	timer.start_at(10.0, 0.0)
	timer.abort()
	timer.update(Vector3(0, 0, -10), Vector3(0, 0, -999.9), 0.0, 1.0)
	timer.update(Vector3(0, 0, -999.9), Vector3(0, 0, -1001), 1.0, 1.1)
	assert_eq(timer.state, RaceTimer.State.ABORTED)
	assert_eq(timer.finish_time, -1.0)
