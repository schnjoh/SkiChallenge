class_name RacingLine
extends RefCounted
## Racing line inside the piste corridor: minimum-curvature relaxation of the OSM centre line.
##
## The line is a lateral offset d(s) from the centre line, bounded by the corridor half width
## minus a safety margin. An elastic band is relaxed at several length scales (long scales first),
## which cuts corners and straightens wiggles. Saved as racing_line.json (editable, F2 editor).

const FILE: String = "racing_line.json"
const STEP_M: float = 2.0


## Corridor width at s from sections.json.
static func width_at(track: TrackData, s: float) -> float:
	var w: float = 30.0
	for sec: Dictionary in track.sections:
		if float(sec["s"]) <= s:
			w = float(sec.get("width_m", w))
	return w


## Lateral offsets d(s) (m, > 0 = right) along the centre line samples.
static func optimize(track: TrackData, margin_m: float = 5.0, iterations: int = 400) -> PackedFloat32Array:
	var c: PackedVector3Array = track.line_points
	var n: int = c.size()
	var normals: PackedVector2Array = PackedVector2Array()
	var limit: PackedFloat32Array = PackedFloat32Array()
	normals.resize(n)
	limit.resize(n)
	for i in n:
		var a: Vector3 = c[maxi(i - 1, 0)]
		var b: Vector3 = c[mini(i + 1, n - 1)]
		var dir: Vector2 = Vector2(b.x - a.x, b.z - a.z).normalized()
		normals[i] = Vector2(-dir.y, dir.x)  # right-hand normal in (x, z)
		limit[i] = maxf(0.0, width_at(track, track.line_s[i]) / 2.0 - margin_m)
	# smooth the limit so the band cannot be forced into kinks at width changes
	var lim_s: PackedFloat32Array = limit.duplicate()
	for i in n:
		var m: float = limit[i]
		for k in range(-10, 11):
			m = minf(m, limit[clampi(i + k, 0, n - 1)] + absf(k) * 0.4)
		lim_s[i] = m
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(n)
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n)
	for scale: int in [24, 12, 6, 3]:
		for it in iterations / 4:
			for i in n:
				pts[i] = Vector2(c[i].x, c[i].z) + normals[i] * d[i]
			for i in range(scale, n - scale):
				var mid: Vector2 = (pts[i - scale] + pts[i + scale]) * 0.5
				var want: float = (mid - Vector2(c[i].x, c[i].z)).dot(normals[i])
				d[i] = clampf(lerpf(d[i], want, 0.5), -lim_s[i], lim_s[i])
	# start and finish stay on the centre line
	for i in mini(10, n):
		d[i] *= float(i) / 10.0
	return d


## Builds the racing line polyline (y on the surface) from offsets.
static func build_points(track: TrackData, d: PackedFloat32Array) -> PackedVector3Array:
	var c: PackedVector3Array = track.line_points
	var n: int = c.size()
	var raw: PackedVector3Array = PackedVector3Array()
	for i in n:
		var a: Vector3 = c[maxi(i - 1, 0)]
		var b: Vector3 = c[mini(i + 1, n - 1)]
		var dir: Vector2 = Vector2(b.x - a.x, b.z - a.z).normalized()
		var p: Vector2 = Vector2(c[i].x, c[i].z) + Vector2(-dir.y, dir.x) * d[i]
		raw.append(Vector3(p.x, track.height_field.height_at(p.x, p.y), p.y))
	return resample(raw, STEP_M, track.height_field)


static func resample(raw: PackedVector3Array, step: float, hf: HeightField) -> PackedVector3Array:
	var path: TrackPath = TrackPath.from_points(raw)
	var out: PackedVector3Array = PackedVector3Array()
	var s: float = 0.0
	while s < path.length():
		var p: Vector3 = path.point_at(s)
		out.append(Vector3(p.x, hf.height_at(p.x, p.z), p.z))
		s += step
	var e: Vector3 = raw[raw.size() - 1]
	out.append(Vector3(e.x, hf.height_at(e.x, e.z), e.z))
	return out


static func save(path: String, pts: PackedVector3Array) -> Error:
	var arr: Array = []
	for p: Vector3 in pts:
		arr.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"note": "Editable racing line (x, y, z) in world metres; F2 editor.",
			"points": arr}))
	return OK


static func load_points(path: String) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if not FileAccess.file_exists(path):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		for p: Variant in (data as Dictionary).get("points", []):
			var a: Array = p
			out.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	return out


## Signed curvature (1/m, > 0 = right turn) at each point, over a +-span window.
static func curvature(pts: PackedVector3Array, span: int = 5) -> PackedFloat32Array:
	var k: PackedFloat32Array = PackedFloat32Array()
	k.resize(pts.size())
	for i in pts.size():
		var a: int = maxi(i - span, 0)
		var b: int = mini(i + span, pts.size() - 1)
		if b - a < 2:
			continue
		var m: int = (a + b) / 2
		var h1: float = SkiPhysics.dir_to_yaw(pts[m] - pts[a])
		var h2: float = SkiPhysics.dir_to_yaw(pts[b] - pts[m])
		var ds: float = Vector2(pts[b].x - pts[a].x, pts[b].z - pts[a].z).length()
		# half-chord headings are half the span apart along the arc
		k[i] = wrapf(h2 - h1, -PI, PI) / maxf(ds * 0.5, 0.1)
	return k
