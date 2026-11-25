class_name CourseBarriers
extends RefCounted
## Safety nets along the piste as 2D polylines (XZ) with a grid index, plus tree trunks as circles.
## Pure logic: resolve() is called after every physics step (player, bot, tests alike).
##
## B nets line both corridor edges; A nets (taller) replace them on the outside of tight turns.
## Contact: the velocity component into the net is reflected with restitution and the rider
## loses speed; hitting it faster than `net_crash_speed` (perpendicular) is a crash.

const CELL: float = 16.0
const NET_GAP_M: float = 1.5  ## nets stand this far outside the corridor edge
const A_NET_RADIUS_M: float = 70.0  ## outside of turns tighter than this get A nets
const RIDER_RADIUS: float = 0.5
const TREE_RADIUS: float = 0.4

var nets: Array[Dictionary] = []  ## {points: PackedVector2Array, kind: "A"/"B", side: -1/1}
var _segs: Array[Dictionary] = []  ## {a, b, kind}
var _grid: Dictionary = {}  ## Vector2i -> Array[int] segment ids
var _trees: Dictionary = {}  ## Vector2i -> PackedVector2Array


static func build(track: TrackData, with_trees: bool = true) -> CourseBarriers:
	var cb: CourseBarriers = CourseBarriers.new()
	var pts: PackedVector3Array = track.line_points
	var k: PackedFloat32Array = RacingLine.curvature(pts, 8)
	for side: float in [-1.0, 1.0]:
		var poly: PackedVector2Array = PackedVector2Array()
		var kinds: PackedStringArray = PackedStringArray()
		for i in range(0, pts.size(), 2):
			var a: Vector3 = pts[maxi(i - 1, 0)]
			var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var dir: Vector2 = Vector2(b.x - a.x, b.z - a.z).normalized()
			var right: Vector2 = Vector2(-dir.y, dir.x)
			var off: float = RacingLine.width_at(track, track.line_s[i]) * 0.5 + NET_GAP_M
			var p: Vector2 = Vector2(pts[i].x, pts[i].z) + right * side * off
			# skip points that fold back on the inside of tight turns
			if poly.size() > 0:
				var step: Vector2 = p - poly[poly.size() - 1]
				if step.length() < 0.5 or step.normalized().dot(dir) < 0.2:
					continue
			poly.append(p)
			# turning right (k > 0): left side (-1) is the outside
			var outside: bool = signf(k[i]) == -side and absf(k[i]) > 1.0 / A_NET_RADIUS_M
			kinds.append("A" if outside else "B")
		# split into runs of equal kind (consecutive runs share the end point)
		var run: PackedVector2Array = PackedVector2Array([poly[0]])
		var kind: String = kinds[0]
		for i in range(1, poly.size()):
			run.append(poly[i])
			if kinds[i] != kind or i == poly.size() - 1:
				cb.nets.append({"points": run, "kind": kind, "side": side})
				run = PackedVector2Array([poly[i]])
				kind = kinds[i]
	cb._index_nets()
	if with_trees:
		cb._index_trees(track)
	return cb


func _index_nets() -> void:
	for n: Dictionary in nets:
		var p: PackedVector2Array = n["points"]
		for i in range(p.size() - 1):
			var id: int = _segs.size()
			_segs.append({"a": p[i], "b": p[i + 1], "kind": n["kind"]})
			var lo: Vector2 = Vector2(minf(p[i].x, p[i + 1].x), minf(p[i].y, p[i + 1].y)) - Vector2.ONE * RIDER_RADIUS
			var hi: Vector2 = Vector2(maxf(p[i].x, p[i + 1].x), maxf(p[i].y, p[i + 1].y)) + Vector2.ONE * RIDER_RADIUS
			for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
				for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
					var key: Vector2i = Vector2i(cx, cz)
					if not _grid.has(key):
						_grid[key] = []
					(_grid[key] as Array).append(id)


func _index_trees(track: TrackData) -> void:
	var vals: PackedFloat32Array = FileAccess.get_file_as_bytes(track.dir.path_join("trees.bin")).to_float32_array()
	for i in range(0, vals.size(), 3):
		var key: Vector2i = Vector2i(floori(vals[i] / CELL), floori(vals[i + 1] / CELL))
		if not _trees.has(key):
			_trees[key] = PackedVector2Array()
		var arr: PackedVector2Array = _trees[key]
		arr.append(Vector2(vals[i], vals[i + 1]))
		_trees[key] = arr


func segment_count() -> int:
	return _segs.size()


## Collides the rider (moved from p0 to phys.pos this step) with nets and trees.
## Returns "" or a short description of the contact ("Netz", "Baum").
func resolve(phys: SkiPhysics, p0: Vector3) -> String:
	var t: SkiTuning = phys.tuning
	var p: Vector2 = Vector2(phys.pos.x, phys.pos.z)
	var key: Vector2i = Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var hit: String = ""
	for id: int in _grid.get(key, []):
		var sg: Dictionary = _segs[id]
		var a: Vector2 = sg["a"]
		var b: Vector2 = sg["b"]
		var ab: Vector2 = b - a
		var q: Vector2 = a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var prev: Vector2 = Vector2(p0.x, p0.z)
		var crossed: bool = GateSet.segment_cross(prev, p, a, b) >= 0.0
		var d: float = p.distance_to(q)
		if d >= RIDER_RADIUS and not crossed:
			continue
		# push back to the side the rider came from
		var nrm: Vector2 = Vector2(-ab.y, ab.x).normalized()
		if (prev - a).dot(nrm) < 0.0:
			nrm = -nrm
		var line_d: float = (p - a).dot(nrm)
		p += nrm * (RIDER_RADIUS - line_d)
		_bounce(phys, nrm, t, "Netz")
		hit = "Netz"
		phys.pos.x = p.x
		phys.pos.z = p.y
	for cx in range(key.x - 1, key.x + 2):
		for cz in range(key.y - 1, key.y + 2):
			for tr: Vector2 in _trees.get(Vector2i(cx, cz), PackedVector2Array()):
				var dv: Vector2 = p - tr
				var dist: float = dv.length()
				if dist < RIDER_RADIUS + TREE_RADIUS and dist > 1e-4:
					p = tr + dv / dist * (RIDER_RADIUS + TREE_RADIUS)
					phys.pos.x = p.x
					phys.pos.z = p.y
					_bounce(phys, dv / dist, t, "Baum")
					hit = "Baum"
	if hit != "":
		phys.pos.y = maxf(phys.pos.y, phys.surface.height_at(phys.pos.x, phys.pos.z))
	return hit


func _bounce(phys: SkiPhysics, nrm2: Vector2, t: SkiTuning, what: String) -> void:
	var n: Vector3 = Vector3(nrm2.x, 0.0, nrm2.y)
	var vn: float = phys.vel.dot(n)
	if vn >= 0.0:
		return
	if -vn > t.net_crash_speed:
		phys.vel -= n * vn * (1.0 + t.net_restitution)
		phys.vel *= t.net_crash_keep
		phys.force_crash("Sturz ins %s (%.0f km/h)" % [what, -vn * 3.6] if what == "Netz" else "Baum getroffen")
		return
	phys.vel -= n * vn * (1.0 + t.net_restitution)
	phys.vel *= 1.0 - t.net_speed_loss
