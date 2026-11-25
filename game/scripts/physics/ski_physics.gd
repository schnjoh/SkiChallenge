class_name SkiPhysics
extends RefCounted
## Deterministic ski physics on a HeightField (no ragdoll, no engine physics).
##
## Each fixed step: integrate gravity + air drag ballistically, then resolve terrain contact.
## Penetration -> the velocity component into the surface is removed; that removal defines the
## normal acceleration N (and the g-load). No penetration -> no contact this step; after
## `liftoff_steps` steps with a gap > `liftoff_clearance` the rider is airborne. Compressions,
## crests and landings therefore all follow from one mechanism. Snow forces (glide friction,
## edge grip, carving, drifting, braking) act only with contact and scale with N.
##
## Conventions: y up, yaw 0 = facing -Z (north), yaw grows clockwise seen from above
## (towards +X / east), so steer > 0 (right) increases yaw. Edge angle > 0 = turning right.

enum Phase { GROUND, AIR, CRASHED }

const G: float = 9.81
const G_FILTER_TAU: float = 0.08  ## smoothing of the g-load (triangle facets cause spikes)

var tuning: SkiTuning
var surface: HeightField

var pos: Vector3 = Vector3.ZERO  ## contact point between the boots
var vel: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var edge_angle: float = 0.0  ## degrees, signed
var tuck_amount: float = 0.0  ## 0 upright .. 1 full tuck
var phase: Phase = Phase.GROUND
var time: float = 0.0
var air_time: float = 0.0
var g_load: float = 1.0
var normal_acc: float = G  ## last contact acceleration (m/s²)
var drifting: bool = false
var skid: float = 0.0  ## 0..1 amount of sideways slip (sound/visuals)
var braking: bool = false
var crash_reason: String = ""
var last_landing_drop: float = 0.0  ## equivalent drop height of the last landing (m)
var landings: int = 0
var max_air_time: float = 0.0
var surface_normal: Vector3 = Vector3.UP

var _gap_steps: int = 0
var _overload_t: float = 0.0
var _prejump_t: float = 0.0
var _in_contact: bool = true


func _init(p_tuning: SkiTuning = null, p_surface: HeightField = null) -> void:
	tuning = p_tuning if p_tuning else SkiTuning.new()
	surface = p_surface


func reset(p: Vector3, heading_yaw: float, speed: float = 0.0) -> void:
	pos = Vector3(p.x, surface.height_at(p.x, p.z), p.z)
	yaw = heading_yaw
	surface_normal = surface.normal_at(pos.x, pos.z)
	vel = _tangent(heading(), surface_normal) * speed
	edge_angle = 0.0
	tuck_amount = 0.0
	phase = Phase.GROUND
	time = 0.0
	air_time = 0.0
	max_air_time = 0.0
	g_load = 1.0
	normal_acc = G
	drifting = false
	skid = 0.0
	braking = false
	crash_reason = ""
	last_landing_drop = 0.0
	landings = 0
	_gap_steps = 0
	_overload_t = 0.0
	_prejump_t = 0.0
	_in_contact = true


static func yaw_to_dir(y: float) -> Vector3:
	return Vector3(sin(y), 0.0, -cos(y))


static func dir_to_yaw(d: Vector3) -> float:
	return atan2(d.x, -d.z)


## Horizontal unit heading of the skis.
func heading() -> Vector3:
	return yaw_to_dir(yaw)


func speed() -> float:
	return vel.length()


func speed_kmh() -> float:
	return vel.length() * 3.6


func is_crashed() -> bool:
	return phase == Phase.CRASHED


func is_airborne() -> bool:
	return phase == Phase.AIR


## Ski axis projected into the tangent plane of normal n.
static func _tangent(d: Vector3, n: Vector3) -> Vector3:
	var t: Vector3 = d - n * d.dot(n)
	return t.normalized() if t.length_squared() > 1e-9 else Vector3.FORWARD


func step(input: SkiInput, dt: float) -> void:
	time += dt
	_prejump_t = maxf(0.0, _prejump_t - dt)
	var crashed: bool = phase == Phase.CRASHED
	braking = input.brake and not crashed

	# --- posture -----------------------------------------------------------------------
	var want_tuck: float = 1.0 if (input.tuck and not input.brake and not crashed) else 0.0
	tuck_amount = move_toward(tuck_amount, want_tuck, tuning.tuck_rate * dt)
	var max_edge: float = tuning.max_edge_angle * lerpf(1.0, tuning.tuck_edge_factor, tuck_amount)
	var target_edge: float = 0.0 if (crashed or phase == Phase.AIR) else input.steer * max_edge
	edge_angle = move_toward(edge_angle, target_edge, tuning.edge_rate * dt)

	# --- pre-jump (Vorspringen): impulse along the surface normal ------------------------
	if input.prejump and phase == Phase.GROUND and _prejump_t <= 0.0:
		vel += surface_normal * tuning.prejump_impulse
		_prejump_t = tuning.prejump_cooldown

	# --- ballistic part: gravity + air drag ----------------------------------------------
	var cda: float = lerpf(tuning.cda_upright, tuning.cda_tuck, tuck_amount)
	if braking:
		cda = tuning.cda_brake
	var spd: float = vel.length()
	var acc: Vector3 = Vector3(0.0, -G, 0.0) - vel * (0.5 * tuning.air_density * cda * spd / tuning.mass)
	vel += acc * dt
	if phase == Phase.AIR:
		yaw += input.steer * tuning.air_yaw_rate * dt
	var p_new: Vector3 = pos + vel * dt

	# --- contact resolution --------------------------------------------------------------
	var h: float = surface.height_at(p_new.x, p_new.z)
	var n: Vector3 = surface.normal_at(p_new.x, p_new.z)
	surface_normal = n
	var was_air: bool = phase == Phase.AIR
	normal_acc = 0.0
	if p_new.y <= h:
		p_new.y = h
		var vn: float = vel.dot(n)
		if vn < 0.0:
			vel -= n * vn
			normal_acc = -vn / dt
		_in_contact = true
		_gap_steps = 0
		if was_air:
			_on_landing(-vn, n)
		elif phase != Phase.CRASHED:
			phase = Phase.GROUND
			# a hard kink in the terrain at speed is an impact just like a landing
			var drop: float = vn * vn / (2.0 * G) if vn < 0.0 else 0.0
			if drop > tuning.landing_crash_drop:
				last_landing_drop = drop
				_crash("Schlag im Gelände (%.1f m)" % drop)
	else:
		_in_contact = false
		if p_new.y - h > tuning.liftoff_clearance:
			_gap_steps += 1
		if phase == Phase.GROUND and _gap_steps >= tuning.liftoff_steps:
			phase = Phase.AIR
			air_time = 0.0
	pos = p_new
	if phase == Phase.AIR:
		air_time += dt
		max_air_time = maxf(max_air_time, air_time)

	# --- snow forces (only with contact) -------------------------------------------------
	if _in_contact:
		if phase == Phase.CRASHED:
			_apply_friction(tuning.crash_friction * normal_acc * dt)
			yaw += 2.0 * dt  # tumbling skis
		else:
			_ski_forces(input, n, dt)
	else:
		drifting = false
		skid = move_toward(skid, 0.0, 4.0 * dt)

	# --- g-load & overload ---------------------------------------------------------------
	var k: float = clampf(dt / G_FILTER_TAU, 0.0, 1.0)
	g_load = lerpf(g_load, normal_acc / G, k)
	if phase == Phase.GROUND and g_load > tuning.overload_crash_g:
		_overload_t += dt
		if _overload_t >= tuning.overload_time:
			_crash("Überlast %.1f g" % g_load)
	else:
		_overload_t = 0.0


func _ski_forces(input: SkiInput, n: Vector3, dt: float) -> void:
	# heading change: carved turn radius R = R_sc * cos(edge) (Howe), engaged above a few degrees
	var f: Vector3 = _tangent(heading(), n)
	var v_long: float = vel.dot(f)
	var edge_abs: float = absf(edge_angle)
	var engage: float = smoothstep(2.0, 15.0, edge_abs)
	var radius: float = tuning.sidecut_radius * cos(deg_to_rad(edge_abs))
	var omega: float = signf(edge_angle) * engage * absf(v_long) / maxf(radius, 1.0)
	# low-speed steering (stepping / pivoting) so the rider can always turn
	if absf(omega) < tuning.min_steer_rate * absf(input.steer):
		omega = tuning.min_steer_rate * input.steer
	if braking and absf(input.steer) > 0.05:
		omega = tuning.pivot_rate * input.steer  # skidded turn
	yaw += omega * dt
	f = _tangent(heading(), n)
	var right: Vector3 = f.cross(n)

	var v_tan: Vector3 = vel - n * vel.dot(n)
	var v_t: float = v_tan.length()
	var v_lat: float = v_tan.dot(right)
	var sgn: float = 1.0 if v_tan.dot(f) >= 0.0 else -1.0
	var grip: float = tuning.edge_grip * normal_acc * (0.35 if braking else 1.0)
	var need: float = absf(v_lat) / dt
	if need <= grip:
		# carving: velocity follows the ski without loss (rotation), small carve drag
		drifting = false
		v_tan = f * sgn * v_t
		_set_tangent(v_tan, n)
		_apply_friction(tuning.carve_drag * engage * normal_acc * dt)
		skid = move_toward(skid, 0.0, 4.0 * dt)
	else:
		# drifting: lateral slip remains, snow pushes sideways and brakes
		drifting = true
		var lat_dv: float = grip * dt * signf(v_lat)
		v_tan -= right * lat_dv
		_set_tangent(v_tan, n)
		var slip: float = clampf(absf(v_lat) / maxf(v_t, 0.1), 0.0, 1.0)
		_apply_friction(tuning.mu_drift * slip * normal_acc * dt)
		skid = move_toward(skid, slip, 6.0 * dt)
	var mu: float = tuning.mu_glide + (tuning.mu_brake if braking else 0.0)
	_apply_friction(mu * normal_acc * dt)


func _set_tangent(v_tan: Vector3, n: Vector3) -> void:
	vel = v_tan + n * vel.dot(n)


## Removes up to dv of speed along the tangential velocity (never reverses it).
func _apply_friction(dv: float) -> void:
	var n: Vector3 = surface_normal
	var v_tan: Vector3 = vel - n * vel.dot(n)
	var v_t: float = v_tan.length()
	if v_t < 1e-6:
		return
	var new_t: float = maxf(0.0, v_t - dv)
	_set_tangent(v_tan * (new_t / v_t), n)


func _on_landing(impact_vn: float, n: Vector3) -> void:
	landings += 1
	last_landing_drop = impact_vn * impact_vn / (2.0 * G) if impact_vn > 0.0 else 0.0
	var air: float = air_time
	air_time = 0.0
	phase = Phase.GROUND
	if air < tuning.min_air_time:
		return
	if last_landing_drop > tuning.landing_crash_drop:
		_crash("Harte Landung (%.1f m)" % last_landing_drop)
		return
	var v_tan: Vector3 = vel - n * vel.dot(n)
	if v_tan.length() > 3.0:
		var ang: float = rad_to_deg(_tangent(heading(), n).angle_to(v_tan.normalized()))
		ang = minf(ang, 180.0 - ang)  # landing backwards counts like forwards (skis are symmetric)
		if ang > tuning.landing_crash_yaw:
			_crash("Verkantet gelandet (%.0f°)" % ang)


func _crash(reason: String) -> void:
	if phase == Phase.CRASHED:
		return
	phase = Phase.CRASHED
	crash_reason = reason
	edge_angle = 0.0
	tuck_amount = 0.0
	drifting = false
