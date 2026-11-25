class_name TrackData
extends RefCounted
## Track description produced by the data pipeline (game/data/<track>/).
##
## World mapping (meta.json): x = E - E0, y = height (m a.s.l.), z = -(N - N0).
## The race line is a polyline of points (x, y, z) with horizontal distance s from the start.

const DEFAULT_DIR: String = "res://data/streif"

var dir: String = DEFAULT_DIR
var meta: Dictionary = {}
var height_field: HeightField
var line_points: PackedVector3Array = PackedVector3Array()
var line_s: PackedFloat32Array = PackedFloat32Array()
var sections: Array[Dictionary] = []


static func load_track(track_dir: String = DEFAULT_DIR) -> TrackData:
	var td: TrackData = TrackData.new()
	td.dir = track_dir
	td.meta = _read_json(track_dir.path_join("meta.json"))
	if td.meta.is_empty():
		push_error("TrackData: meta.json missing in %s" % track_dir)
		return null
	var core: Dictionary = td.meta["core"]
	td.height_field = HeightField.load_r32(track_dir.path_join(str(core["file"])),
			int(core["width"]), int(core["height"]), float(core["res_m"]),
			float(core["world_min_x"]), float(core["world_min_z"]))
	if td.height_field == null:
		return null
	var line: Dictionary = _read_json(track_dir.path_join("line.json"))
	for p: Variant in line.get("points", []):
		var a: Array = p
		td.line_points.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
		td.line_s.append(float(a[3]))
	var sec: Dictionary = _read_json(track_dir.path_join("sections.json"))
	for s: Variant in sec.get("sections", []):
		td.sections.append(s as Dictionary)
	return td


static func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var data: Variant = JSON.parse_string(text)
	return data if data is Dictionary else {}


func length() -> float:
	return line_s[line_s.size() - 1] if line_s.size() > 0 else 0.0


func start_point() -> Vector3:
	return line_points[0]


func finish_point() -> Vector3:
	return line_points[line_points.size() - 1]


## Index i with line_s[i] <= s < line_s[i + 1] (binary search).
func _segment_at(s: float) -> int:
	var lo: int = 0
	var hi: int = line_s.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if line_s[mid] <= s:
			lo = mid
		else:
			hi = mid
	return lo


## Point on the race line at horizontal distance s (clamped).
func point_at(s: float) -> Vector3:
	s = clampf(s, 0.0, length())
	var i: int = _segment_at(s)
	var ds: float = line_s[i + 1] - line_s[i]
	var t: float = (s - line_s[i]) / ds if ds > 0.0 else 0.0
	return line_points[i].lerp(line_points[i + 1], t)


## Horizontal unit direction of the race line at s.
func direction_at(s: float) -> Vector3:
	var i: int = _segment_at(clampf(s, 0.0, length()))
	var d: Vector3 = line_points[i + 1] - line_points[i]
	d.y = 0.0
	return d.normalized()


## Distance s of the closest point on the line to pos (horizontal). ``hint`` narrows the search.
func project(pos: Vector3, hint_s: float = -1.0, window_m: float = 60.0) -> float:
	var i0: int = 0
	var i1: int = line_points.size() - 2
	if hint_s >= 0.0:
		i0 = maxi(0, _segment_at(hint_s - window_m))
		i1 = mini(line_points.size() - 2, _segment_at(hint_s + window_m) + 1)
	var best_d: float = INF
	var best_s: float = 0.0
	var p: Vector2 = Vector2(pos.x, pos.z)
	for i in range(i0, i1 + 1):
		var a: Vector2 = Vector2(line_points[i].x, line_points[i].z)
		var b: Vector2 = Vector2(line_points[i + 1].x, line_points[i + 1].z)
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var d: float = p.distance_squared_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_s = line_s[i] + (line_s[i + 1] - line_s[i]) * t
	return best_s


func section_at(s: float) -> String:
	var name: String = "Start"
	for sec: Dictionary in sections:
		if float(sec["s"]) <= s:
			name = str(sec["name"])
	return name


func section_s(section_name: String) -> float:
	for sec: Dictionary in sections:
		if str(sec["name"]) == section_name:
			return float(sec["s"])
	return -1.0
