class_name GateSet
extends RefCounted
## Gates and timing lines of a track (gates.json, editable in the F2 editor).
##
## Gate = segment left-right in XZ (min. width 8 m), passed in order. Split/finish lines are
## positions s on the centre line; the timer interpolates crossings within a physics step.

const FILE: String = "gates.json"
const MIN_WIDTH: float = 8.0
## Split positions from DESIGN.md §3 (centre-line s, m) and their names.
const DEFAULT_SPLITS: Array[Dictionary] = [
	{"name": "Mausefalle", "s": 300.0}, {"name": "Steilhang", "s": 700.0},
	{"name": "Alte Schneise", "s": 1400.0}, {"name": "Lärchenschuss", "s": 2050.0},
	{"name": "Hausbergkante", "s": 2450.0},
]

var gates: Array[Dictionary] = []  ## {id, left: Vector2, right: Vector2, s: float (centre line)}
var splits: Array[Dictionary] = []  ## {name, s}
var start_s: float = 2.0  ## start trigger on the centre line
var finish_s: float = 0.0  ## finish line on the centre line


static func generate(track: TrackData, spacing_m: float = 95.0, curve_gain: float = 900.0,
		width_m: float = 14.0) -> GateSet:
	var gs: GateSet = GateSet.new()
	var path: TrackPath = track.race_path()
	var k: PackedFloat32Array = RacingLine.curvature(path.points, 6)
	var acc: float = spacing_m * 0.6
	var last_s: float = -INF
	for i in range(1, path.points.size()):
		var ds: float = path.s[i] - path.s[i - 1]
		acc += ds * (1.0 + absf(k[i]) * curve_gain / 10.0)
		var s: float = path.s[i]
		if acc >= spacing_m and s - last_s >= 40.0 and s > 60.0 and s < path.length() - 40.0:
			acc = 0.0
			last_s = s
			var c: Vector3 = path.points[i]
			var d: Vector3 = path.direction_at(s)
			var right: Vector2 = Vector2(-d.z, d.x)
			var w: float = minf(width_m, RacingLine.width_at(track, track.project(c)) - 2.0)
			w = maxf(w, MIN_WIDTH)
			var cc: Vector2 = Vector2(c.x, c.z)
			gs.gates.append({"left": cc - right * w * 0.5, "right": cc + right * w * 0.5})
	for sp: Dictionary in DEFAULT_SPLITS:
		gs.splits.append(sp.duplicate())
	gs.finish_s = track.length()
	gs.finalize(track)
	return gs


## Recomputes ids and centre-line positions (after loading or editing).
func finalize(track: TrackData) -> void:
	for i in gates.size():
		var g: Dictionary = gates[i]
		g["id"] = i + 1
		var mid: Vector2 = ((g["left"] as Vector2) + (g["right"] as Vector2)) * 0.5
		g["s"] = track.project(Vector3(mid.x, 0.0, mid.y))
	gates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	for i in gates.size():
		gates[i]["id"] = i + 1
	if finish_s <= 0.0:
		finish_s = track.length()


func to_dict() -> Dictionary:
	var arr: Array = []
	for g: Dictionary in gates:
		var l: Vector2 = g["left"]
		var r: Vector2 = g["right"]
		arr.append({"id": g["id"], "left": [snappedf(l.x, 0.01), snappedf(l.y, 0.01)],
				"right": [snappedf(r.x, 0.01), snappedf(r.y, 0.01)]})
	return {"note": "Editable: gates (x, z) left/right in world metres, splits/finish as centre-line s. F2 editor.",
			"start_s": start_s, "finish_s": snappedf(finish_s, 0.01), "splits": splits, "gates": arr}


func save(path: String) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t", false))
	return OK


static func load_file(path: String, track: TrackData) -> GateSet:
	var gs: GateSet = GateSet.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	gs.start_s = float(d.get("start_s", 2.0))
	gs.finish_s = float(d.get("finish_s", 0.0))
	for sp: Variant in d.get("splits", []):
		gs.splits.append({"name": str((sp as Dictionary)["name"]), "s": float((sp as Dictionary)["s"])})
	for g: Variant in d.get("gates", []):
		var gd: Dictionary = g
		var l: Array = gd["left"]
		var r: Array = gd["right"]
		gs.gates.append({"left": Vector2(float(l[0]), float(l[1])), "right": Vector2(float(r[0]), float(r[1]))})
	gs.finalize(track)
	return gs


## Gates for a track: gates.json if present, otherwise generated from the racing line.
static func for_track(track: TrackData) -> GateSet:
	var gs: GateSet = load_file(track.dir.path_join(FILE), track)
	return gs if gs != null else generate(track)


## Parameter t (0..1) where segment p0->p1 crosses segment a->b, or -1.
static func segment_cross(p0: Vector2, p1: Vector2, a: Vector2, b: Vector2) -> float:
	var r: Vector2 = p1 - p0
	var sv: Vector2 = b - a
	var den: float = r.cross(sv)
	if absf(den) < 1e-9:
		return -1.0
	var t: float = (a - p0).cross(sv) / den
	var u: float = (a - p0).cross(r) / den
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return t
	return -1.0
