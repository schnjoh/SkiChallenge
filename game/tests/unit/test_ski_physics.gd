extends GutTest
## SkiPhysics against closed-form results on synthetic surfaces.

const DT: float = 1.0 / 120.0


## Height field from h(x, z) on a square grid (spacing m) centred on the origin.
func _surface(f: Callable, size_m: float, spacing: float) -> HeightField:
	var n: int = int(size_m / spacing) + 1
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(n * n)
	var x0: float = -size_m / 2.0
	for r in n:
		for c in n:
			data[r * n + c] = f.call(x0 + c * spacing, x0 + r * spacing)
	return HeightField.from_array(data, n, n, spacing, x0, x0)


## Plane falling towards -z (north) with gradient `grad` (rise per metre).
func _slope(grad: float) -> HeightField:
	return _surface(func(_x: float, z: float) -> float: return grad * z, 20000.0, 10000.0)


func _run(phys: SkiPhysics, input: SkiInput, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		phys.step(input, DT)


func _no_losses(t: SkiTuning) -> void:
	t.mu_glide = 0.0
	t.carve_drag = 0.0
	t.cda_tuck = 0.0
	t.cda_upright = 0.0


func test_frictionless_slope_acceleration() -> void:
	var t: SkiTuning = SkiTuning.new()
	_no_losses(t)
	var phys: SkiPhysics = SkiPhysics.new(t, _slope(0.5))
	phys.reset(Vector3.ZERO, 0.0)
	_run(phys, SkiInput.make(0.0, true), 2.0)
	var alpha: float = atan(0.5)
	assert_almost_eq(phys.speed(), SkiPhysics.G * sin(alpha) * 2.0, 0.05)
	assert_eq(phys.phase, SkiPhysics.Phase.GROUND)
	assert_almost_eq(phys.g_load, cos(alpha), 0.02)


func test_terminal_speed_tuck_matches_closed_form() -> void:
	var t: SkiTuning = SkiTuning.new()
	var grad: float = 0.3
	var phys: SkiPhysics = SkiPhysics.new(t, _slope(grad))
	phys.reset(Vector3.ZERO, 0.0)
	_run(phys, SkiInput.make(0.0, true), 150.0)
	var a: float = atan(grad)
	var v_term: float = sqrt(2.0 * t.mass * SkiPhysics.G * (sin(a) - t.mu_glide * cos(a)) / (t.air_density * t.cda_tuck))
	assert_almost_eq(phys.speed(), v_term, v_term * 0.03)


func test_tuck_is_faster_than_upright() -> void:
	var tuck: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.3))
	var up: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.3))
	tuck.reset(Vector3.ZERO, 0.0)
	up.reset(Vector3.ZERO, 0.0)
	_run(tuck, SkiInput.make(0.0, true), 20.0)
	_run(up, SkiInput.make(0.0, false), 20.0)
	assert_gt(tuck.speed(), up.speed() * 1.15)


func test_carving_keeps_speed_better_than_skidding() -> void:
	var carve: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.3))
	var skid: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.3))
	carve.reset(Vector3.ZERO, 0.0, 20.0)
	skid.reset(Vector3.ZERO, 0.0, 20.0)
	_run(carve, SkiInput.make(0.6, false), 1.5)
	_run(skid, SkiInput.make(0.6, false, true), 1.5)
	assert_gt(carve.yaw, 0.3, "carving turns right")
	assert_false(carve.drifting)
	assert_gt(carve.speed(), skid.speed() + 3.0, "skidding brakes")


func test_carve_radius_follows_sidecut() -> void:
	# flat ground, fixed edge angle: radius = R_sc * cos(edge)
	var t: SkiTuning = SkiTuning.new()
	_no_losses(t)
	t.edge_grip = 6.0
	var phys: SkiPhysics = SkiPhysics.new(t, _slope(0.0))
	phys.reset(Vector3.ZERO, 0.0, 15.0)
	var inp: SkiInput = SkiInput.make(0.5, false)
	_run(phys, inp, 1.0)  # edge settles
	var y0: float = phys.yaw
	_run(phys, inp, 1.0)
	var omega: float = phys.yaw - y0
	var expected: float = 15.0 / (t.sidecut_radius * cos(deg_to_rad(t.max_edge_angle * 0.5)))
	assert_almost_eq(omega, expected, expected * 0.05)


func test_liftoff_at_crest_and_soft_landing() -> void:
	# 15 % slope, then a sudden 50 % slope beyond z < 0 (convex kink)
	var hf: HeightField = _surface(func(_x: float, z: float) -> float:
		return 0.15 * z if z >= 0.0 else 0.5 * z, 600.0, 1.0)
	var phys: SkiPhysics = SkiPhysics.new(SkiTuning.new(), hf)
	phys.reset(Vector3(0.0, 0.0, 60.0), 0.0, 25.0)
	_run(phys, SkiInput.make(0.0, true), 6.0)  # ~2.4 s run-up + ~1.8 s flight
	assert_gt(phys.max_air_time, 0.4, "rider flies over the kink")
	assert_eq(phys.landings, 1)
	assert_false(phys.is_crashed(), phys.crash_reason)


func test_hard_landing_crashes_soft_does_not() -> void:
	var flat: HeightField = _slope(0.0)
	var hard: SkiPhysics = SkiPhysics.new(SkiTuning.new(), flat)
	hard.reset(Vector3.ZERO, 0.0, 10.0)
	hard.pos.y = 6.0
	hard.phase = SkiPhysics.Phase.AIR
	_run(hard, SkiInput.make(0.0, true), 2.0)
	assert_true(hard.is_crashed())
	assert_string_contains(hard.crash_reason, "Landung")
	var soft: SkiPhysics = SkiPhysics.new(SkiTuning.new(), flat)
	soft.reset(Vector3.ZERO, 0.0, 10.0)
	soft.pos.y = 1.0
	soft.phase = SkiPhysics.Phase.AIR
	_run(soft, SkiInput.make(0.0, true), 2.0)
	assert_false(soft.is_crashed(), soft.crash_reason)


func test_crossways_landing_crashes() -> void:
	var phys: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.0))
	phys.reset(Vector3.ZERO, 0.0, 15.0)
	phys.yaw = PI / 2.0  # skis across the direction of travel
	phys.pos.y = 0.5
	phys.phase = SkiPhysics.Phase.AIR
	_run(phys, SkiInput.make(0.0, true), 1.0)
	assert_true(phys.is_crashed())


## Concave circular dip: g = v²/(R g) + 1 at the bottom.
func _dip(radius: float) -> HeightField:
	return _surface(func(_x: float, z: float) -> float:
		var zz: float = clampf(z, -radius * 0.7, radius * 0.7)
		var circ: float = radius - sqrt(radius * radius - zz * zz)
		return circ + (absf(z) - absf(zz)) * (zz / sqrt(radius * radius - zz * zz)) * signf(z) * signf(zz), 400.0, 0.5)


func test_compression_g_load_and_overload_crash() -> void:
	var t: SkiTuning = SkiTuning.new()
	_no_losses(t)
	var mild: SkiPhysics = SkiPhysics.new(t, _dip(60.0))
	mild.reset(Vector3(0.0, 0.0, 30.0), 0.0, 25.0)
	var peak: float = 0.0
	for i in 240:
		mild.step(SkiInput.make(0.0, true), DT)
		peak = maxf(peak, mild.g_load)
	var v: float = 25.0
	assert_almost_eq(peak, v * v / (60.0 * SkiPhysics.G) + 1.0, 0.5)
	assert_false(mild.is_crashed(), mild.crash_reason)
	var hard: SkiPhysics = SkiPhysics.new(t, _dip(12.0))
	hard.reset(Vector3(0.0, 0.0, 8.0), 0.0, 25.0)
	_run(hard, SkiInput.make(0.0, true), 2.0)
	assert_true(hard.is_crashed(), "tight compression at 90 km/h")


func test_prejump_lifts_off() -> void:
	var phys: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.2))
	phys.reset(Vector3.ZERO, 0.0, 15.0)
	phys.step(SkiInput.make(0.0, true, false, true), DT)
	_run(phys, SkiInput.make(0.0, true), 0.2)
	assert_true(phys.is_airborne() or phys.max_air_time > 0.0)


func test_deterministic() -> void:
	var a: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.35))
	var b: SkiPhysics = SkiPhysics.new(SkiTuning.new(), _slope(0.35))
	a.reset(Vector3.ZERO, 0.1)
	b.reset(Vector3.ZERO, 0.1)
	for i in 600:
		var inp: SkiInput = SkiInput.make(sin(i * 0.02), i % 200 < 150)
		a.step(inp, DT)
		b.step(inp, DT)
	assert_eq(a.pos, b.pos)
	assert_eq(a.vel, b.vel)


func test_tuning_json_roundtrip() -> void:
	var t: SkiTuning = SkiTuning.new()
	t.mu_glide = 0.042
	t.liftoff_steps = 3
	var path: String = "user://test_tuning.json"
	assert_eq(t.save_json(path), OK)
	var u: SkiTuning = SkiTuning.load_json(path)
	assert_almost_eq(u.mu_glide, 0.042, 1e-6)
	assert_eq(u.liftoff_steps, 3)
	assert_gt(t.tunable_properties().size(), 25)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
