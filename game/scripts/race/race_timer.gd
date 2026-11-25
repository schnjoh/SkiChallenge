class_name RaceTimer
extends RefCounted
## Race state machine: start, gates in order, split times, finish, disqualification.
## Fed once per physics step with the positions before/after the step (also in the air).

signal gate_passed(index: int)
signal split(index: int, time: float)
signal finished(time: float)
signal disqualified(reason: String)

enum State { READY, RUNNING, FINISHED, DSQ }

const MISS_TOLERANCE_M: float = 25.0  ## s past a gate without passing it -> DSQ

var track: TrackData
var gates: GateSet
var state: State = State.READY
var start_time: float = 0.0  ## physics time when the start line was crossed
var race_time: float = 0.0
var next_gate: int = 0
var split_times: PackedFloat32Array = PackedFloat32Array()
var finish_time: float = -1.0
var dsq_reason: String = ""
var s_now: float = 0.0  ## centre-line s of the rider


func _init(p_track: TrackData, p_gates: GateSet) -> void:
	track = p_track
	gates = p_gates


func reset() -> void:
	state = State.READY
	start_time = 0.0
	race_time = 0.0
	next_gate = 0
	split_times = PackedFloat32Array()
	finish_time = -1.0
	dsq_reason = ""
	s_now = 0.0


func is_running() -> bool:
	return state == State.RUNNING


## One physics step from p0 (time t0) to p1 (time t1).
func update(p0: Vector3, p1: Vector3, t0: float, t1: float) -> void:
	var s0: float = s_now
	var s1: float = track.project(p1, s0, 40.0)
	s_now = s1
	if state == State.READY:
		if s1 >= gates.start_s and s0 < gates.start_s:
			start_time = _lerp_time(s0, s1, gates.start_s, t0, t1)
			state = State.RUNNING
		elif s1 >= gates.start_s:
			start_time = t0  # spawned past the start trigger (training restarts)
			state = State.RUNNING
		else:
			return
	if state != State.RUNNING:
		return
	race_time = t1 - start_time
	# gates (crossing in XZ, in order)
	var a: Vector2 = Vector2(p0.x, p0.z)
	var b: Vector2 = Vector2(p1.x, p1.z)
	while next_gate < gates.gates.size():
		var g: Dictionary = gates.gates[next_gate]
		if GateSet.segment_cross(a, b, g["left"], g["right"]) >= 0.0:
			next_gate += 1
			gate_passed.emit(next_gate - 1)
			continue
		if s1 > float(g["s"]) + MISS_TOLERANCE_M:
			_dsq("Tor %d ausgelassen" % int(g["id"]))
			return
		break
	# splits
	while split_times.size() < gates.splits.size():
		var sp_s: float = float(gates.splits[split_times.size()]["s"])
		if s1 < sp_s:
			break
		var ts: float = _lerp_time(s0, s1, sp_s, t0, t1) - start_time
		split_times.append(ts)
		split.emit(split_times.size() - 1, ts)
	# finish
	if s1 >= gates.finish_s and s0 < gates.finish_s:
		if next_gate < gates.gates.size():
			_dsq("Tor %d ausgelassen" % int(gates.gates[next_gate]["id"]))
			return
		finish_time = _lerp_time(s0, s1, gates.finish_s, t0, t1) - start_time
		race_time = finish_time
		state = State.FINISHED
		finished.emit(finish_time)


func _lerp_time(s0: float, s1: float, s_line: float, t0: float, t1: float) -> float:
	if s1 - s0 <= 1e-6:
		return t1
	return lerpf(t0, t1, clampf((s_line - s0) / (s1 - s0), 0.0, 1.0))


func _dsq(reason: String) -> void:
	state = State.DSQ
	dsq_reason = reason
	disqualified.emit(reason)


## Formats seconds as m:ss.cc
static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--.--"
	var cs: int = int(round(t * 100.0))
	return "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]


## Signed difference as +s.cc / -s.cc
static func format_delta(d: float) -> String:
	return ("+" if d >= 0.0 else "-") + "%.2f" % absf(d)
