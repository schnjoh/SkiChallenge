class_name BotDriver
extends RefCounted
## Validation bot: pure-pursuit steering along a path + posture logic from a speed profile.
## Pure logic (no nodes) so it runs headless and deterministically.

var path: TrackPath
var lookahead_time: float = 0.55  ## s of travel ahead for the pursuit point
var lookahead_min: float = 10.0
var lookahead_max: float = 45.0
var steer_gain: float = 2.2  ## steer per radian of heading error
var speed_limits: Array[Dictionary] = []  ## [{s0, s1, kmh}] brake above these speeds
var prejump_at: PackedFloat32Array = PackedFloat32Array()  ## s positions to pop before
var prejump_lead_s: float = 0.25
var s: float = 0.0
var _jump_idx: int = 0


func _init(p_path: TrackPath) -> void:
	path = p_path


func reset() -> void:
	s = 0.0
	_jump_idx = 0


func limit_at(p_s: float) -> float:
	var lim: float = INF
	for l: Dictionary in speed_limits:
		if p_s >= float(l["s0"]) and p_s <= float(l["s1"]):
			lim = minf(lim, float(l["kmh"]))
	return lim


func drive(phys: SkiPhysics) -> SkiInput:
	s = path.project(phys.pos, s)
	var v: float = phys.speed()
	var look: float = clampf(v * lookahead_time, lookahead_min, lookahead_max)
	var target: Vector3 = path.point_at(s + look)
	var to: Vector3 = target - phys.pos
	to.y = 0.0
	var want_yaw: float = SkiPhysics.dir_to_yaw(to)
	var err: float = wrapf(want_yaw - phys.yaw, -PI, PI)
	var steer: float = clampf(err * steer_gain, -1.0, 1.0)
	var kmh: float = v * 3.6
	var lim: float = limit_at(s)
	var brake: bool = kmh > lim
	var tuck: bool = not brake and absf(steer) < 0.85
	var pop: bool = false
	while _jump_idx < prejump_at.size() and s > prejump_at[_jump_idx]:
		_jump_idx += 1
	if _jump_idx < prejump_at.size() and v > 1.0:
		var t_to: float = (prejump_at[_jump_idx] - s) / v
		if t_to <= prejump_lead_s:
			pop = true
			_jump_idx += 1
	return SkiInput.make(steer, tuck, brake, pop)
