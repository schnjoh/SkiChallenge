class_name BotRun
extends RefCounted
## Headless validation run: the bot drives the whole track with physics + race timer and
## collects the metrics checked against the research (docs/validation.md, DESIGN §4.7).

const DT: float = 1.0 / 120.0
const MAX_TIME: float = 300.0
const LANDING_G_IGNORE_S: float = 0.3  ## landing impacts are judged by the drop height instead

var track: TrackData
var tuning: SkiTuning
var gates: GateSet
var bot: BotDriver
var phys: SkiPhysics
var timer: RaceTimer

# results
var time: float = -1.0
var finished: bool = false
var crash_reason: String = ""
var dsq_reason: String = ""
var vmax_kmh: float = 0.0
var gmax: float = 0.0
var gmax_s: float = 0.0
var t_100kmh: float = -1.0
var s_100kmh: float = -1.0
var jumps: Array[Dictionary] = []  ## {s0, s1, length (3D, m), v0_kmh, drop}
var sections: Array[Dictionary] = []  ## {name, s0, s1, t, avg_kmh, min_kmh, max_kmh}
var split_times: PackedFloat32Array = PackedFloat32Array()
var gates_passed: int = 0
var final_pos: Vector3 = Vector3.ZERO


func _init(p_track: TrackData, p_tuning: SkiTuning, p_gates: GateSet = null) -> void:
	track = p_track
	tuning = p_tuning
	gates = p_gates if p_gates != null else GateSet.for_track(track)


func run() -> BotRun:
	bot = BotDriver.for_track(track)
	phys = SkiPhysics.new(tuning, track.height_field)
	phys.reset(track.start_point(), SkiPhysics.dir_to_yaw(track.direction_at(0.0)), tuning.start_speed)
	timer = RaceTimer.new(track, gates)
	var air_s0: float = 0.0
	var air_v0: float = 0.0
	var air_p0: Vector3 = Vector3.ZERO
	var was_air: bool = false
	var since_landing: float = 10.0
	var sec_name: String = track.section_at(0.0)
	var sec: Dictionary = _new_section(sec_name, 0.0, 0.0)
	while phys.time < MAX_TIME:
		var p0: Vector3 = phys.pos
		var t0: float = phys.time
		phys.step(bot.drive(phys), DT)
		timer.update(p0, phys.pos, t0, phys.time)
		var kmh: float = phys.speed_kmh()
		var cs: float = timer.s_now
		vmax_kmh = maxf(vmax_kmh, kmh)
		if t_100kmh < 0.0 and kmh >= 100.0:
			t_100kmh = phys.time
			s_100kmh = cs
		since_landing += DT
		if phys.is_airborne() and not was_air:
			air_s0 = cs
			air_v0 = kmh
			air_p0 = phys.pos
		elif was_air and not phys.is_airborne():
			since_landing = 0.0
			if cs - air_s0 > 3.0:  # length measured like ski jumping: take-off to landing point (3D)
				jumps.append({"s0": air_s0, "s1": cs, "length": air_p0.distance_to(phys.pos), "v0_kmh": air_v0,
						"drop": phys.last_landing_drop})
		was_air = phys.is_airborne()
		if not phys.is_airborne() and since_landing > LANDING_G_IGNORE_S and phys.g_load > gmax:
			gmax = phys.g_load
			gmax_s = cs
		sec["min_kmh"] = minf(sec["min_kmh"], kmh)
		sec["max_kmh"] = maxf(sec["max_kmh"], kmh)
		var name_now: String = track.section_at(cs)
		if name_now != sec_name:
			_close_section(sec, cs, phys.time)
			sec_name = name_now
			sec = _new_section(sec_name, cs, phys.time)
		if phys.is_crashed():
			crash_reason = phys.crash_reason
			break
		if timer.state == RaceTimer.State.DSQ:
			dsq_reason = timer.dsq_reason
			break
		if timer.state == RaceTimer.State.FINISHED:
			finished = true
			time = timer.finish_time
			break
	_close_section(sec, timer.s_now, phys.time)
	split_times = timer.split_times
	gates_passed = timer.next_gate
	final_pos = phys.pos
	return self


func _new_section(n: String, s0: float, t0: float) -> Dictionary:
	return {"name": n, "s0": s0, "t0": t0, "min_kmh": INF, "max_kmh": 0.0}


func _close_section(sec: Dictionary, s1: float, t1: float) -> void:
	var dt: float = t1 - float(sec["t0"])
	sec["s1"] = s1
	sec["t"] = dt
	sec["avg_kmh"] = (s1 - float(sec["s0"])) / maxf(dt, 1e-3) * 3.6
	sections.append(sec)


## Jump starting closest to centre-line s (within 25 m), or {}.
func jump_near(s: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = 25.0
	for j: Dictionary in jumps:
		var d: float = absf(float(j["s0"]) - s)
		if d < best_d:
			best_d = d
			best = j
	return best


func avg_kmh() -> float:
	return track.length() / time * 3.6 if time > 0.0 else 0.0
