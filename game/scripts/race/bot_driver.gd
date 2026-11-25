class_name BotDriver
extends RefCounted
## Validation bot: pure-pursuit steering along a path + posture logic from a speed profile.
## Pure logic (no nodes) so it runs headless and deterministically.

const BOT_LATERAL_ACC: float = 16.0  ## m/s², curvature speed cap
const BOT_DECEL: float = 4.0  ## m/s², assumed braking for the backwards pass
const JUMP_APPROACH_M: float = 60.0
const JUMP_SPEED_MARGIN_KMH: float = 3.0
const USE_PREJUMP: bool = true  ## pop 0.25-0.3 s before the lips from jumps.json (DESIGN §4.7)

var path: TrackPath
var lookahead_time: float = 0.55  ## s of travel ahead for the pursuit point
var lookahead_min: float = 10.0
var lookahead_max: float = 45.0
var steer_gain: float = 2.2  ## steer per radian of heading error
var speed_limits: Array[Dictionary] = []  ## [{s0, s1, kmh}] brake above these speeds
var prejump_at: PackedFloat32Array = PackedFloat32Array()  ## s positions to pop before
var prejump_lead_s: float = 0.3
var speed_cap: PackedFloat32Array = PackedFloat32Array()  ## m/s per path point (curvature limit)
var s: float = -1.0
var _jump_idx: int = 0


func _init(p_path: TrackPath) -> void:
	path = p_path


## Bot for a track: racing line, curvature speed cap, design speeds before jumps, section limits.
static func for_track(track: TrackData) -> BotDriver:
	var b: BotDriver = BotDriver.new(track.race_path())
	b.build_speed_cap(BOT_LATERAL_ACC, BOT_DECEL)
	for j: Dictionary in track.jumps:
		var lip: float = b.path.project(track.point_at(float(j["s_lip"])))
		b.speed_limits.append({"s0": lip - JUMP_APPROACH_M, "s1": lip + 2.0,
				"kmh": float(j["v_kmh"]) + JUMP_SPEED_MARGIN_KMH})
		if USE_PREJUMP:
			b.prejump_at.append(lip)
	return b


## s = -1: the next drive() projects globally (after a restart anywhere on the course).
func reset() -> void:
	s = -1.0
	_jump_idx = 0


## Speed cap from the path curvature: lateral load a_lat (m/s^2), backwards pass with decel (m/s^2).
func build_speed_cap(a_lat: float, decel: float) -> void:
	var k: PackedFloat32Array = RacingLine.curvature(path.points, 6)
	var n: int = path.points.size()
	speed_cap.resize(n)
	for i in n:
		speed_cap[i] = sqrt(a_lat / maxf(absf(k[i]), 1e-4))
	for i in range(n - 2, -1, -1):
		var ds: float = path.s[i + 1] - path.s[i]
		speed_cap[i] = minf(speed_cap[i], sqrt(speed_cap[i + 1] * speed_cap[i + 1] + 2.0 * decel * ds))


func limit_at(p_s: float) -> float:
	var lim: float = INF
	if speed_cap.size() == path.points.size():
		lim = speed_cap[path._segment_at(p_s)] * 3.6
	for l: Dictionary in speed_limits:
		if p_s >= float(l["s0"]) and p_s <= float(l["s1"]):
			lim = minf(lim, float(l["kmh"]))
	return lim


func drive(phys: SkiPhysics) -> SkiInput:
	s = path.project(phys.pos, s)  # hint -1 -> global search
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
