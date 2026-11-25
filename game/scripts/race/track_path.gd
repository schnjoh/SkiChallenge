class_name TrackPath
extends RefCounted
## Horizontal polyline with arc length s (race line or OSM centre line).

var points: PackedVector3Array = PackedVector3Array()
var s: PackedFloat32Array = PackedFloat32Array()


static func from_points(pts: PackedVector3Array) -> TrackPath:
	var p: TrackPath = TrackPath.new()
	p.points = pts
	var acc: float = 0.0
	for i in pts.size():
		if i > 0:
			acc += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		p.s.append(acc)
	return p


func length() -> float:
	return s[s.size() - 1] if s.size() > 0 else 0.0


func _segment_at(p_s: float) -> int:
	var lo: int = 0
	var hi: int = s.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if s[mid] <= p_s:
			lo = mid
		else:
			hi = mid
	return lo


func point_at(p_s: float) -> Vector3:
	p_s = clampf(p_s, 0.0, length())
	var i: int = _segment_at(p_s)
	var ds: float = s[i + 1] - s[i]
	var t: float = (p_s - s[i]) / ds if ds > 0.0 else 0.0
	return points[i].lerp(points[i + 1], t)


func direction_at(p_s: float) -> Vector3:
	var i: int = _segment_at(clampf(p_s, 0.0, length()))
	var d: Vector3 = points[i + 1] - points[i]
	d.y = 0.0
	return d.normalized()


## Arc length of the closest point (horizontal); hint_s >= 0 restricts the search window.
func project(pos: Vector3, hint_s: float = -1.0, window_m: float = 60.0) -> float:
	var i0: int = 0
	var i1: int = points.size() - 2
	if hint_s >= 0.0:
		i0 = maxi(0, _segment_at(hint_s - window_m))
		i1 = mini(points.size() - 2, _segment_at(hint_s + window_m) + 1)
	var best_d: float = INF
	var best_s: float = 0.0
	var p: Vector2 = Vector2(pos.x, pos.z)
	for i in range(i0, i1 + 1):
		var a: Vector2 = Vector2(points[i].x, points[i].z)
		var b: Vector2 = Vector2(points[i + 1].x, points[i + 1].z)
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var d: float = p.distance_squared_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_s = s[i] + (s[i + 1] - s[i]) * t
	return best_s


## Signed lateral offset of pos from the path (m, > 0 = right of travel direction).
func lateral_offset(pos: Vector3, at_s: float) -> float:
	var c: Vector3 = point_at(at_s)
	var d: Vector3 = direction_at(at_s)
	var right: Vector3 = Vector3(-d.z, 0.0, d.x)
	return (pos - c).dot(right)
