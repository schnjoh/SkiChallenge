class_name CourseBuilder
extends Node3D
## Visual race furniture built from primitives: A/B nets, gates, start house, finish area.
## No logos or sponsor marks (CLAUDE.md); colours only.

const NET_SHADER: String = "res://scripts/race/net.gdshader"
const B_NET_H: float = 1.8
const A_NET_H: float = 4.0
const POST_SPACING: float = 8.0
const GATE_POLE_H: float = 1.9
const GATE_COLORS: Array[Color] = [Color(0.85, 0.1, 0.1), Color(0.1, 0.25, 0.85)]

var track: TrackData
var gates: GateSet
var barriers: CourseBarriers
var gate_nodes: Array[Node3D] = []  ## per gate: {left pole+panel, right pole+panel} parent
var _mat_cache: Dictionary = {}


func build(p_track: TrackData, p_gates: GateSet, p_barriers: CourseBarriers) -> void:
	track = p_track
	gates = p_gates
	barriers = p_barriers
	for c: Node in get_children():
		c.queue_free()
	gate_nodes.clear()
	_build_nets()
	rebuild_gates()
	_build_start_house()
	_build_finish()


func _mat(c: Color, rough: float = 0.7) -> StandardMaterial3D:
	var key: String = c.to_html() + str(rough)
	if not _mat_cache.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mat_cache[key] = m
	return _mat_cache[key]


func _ground(x: float, z: float) -> float:
	return track.height_field.height_at(x, z)


# --- nets ---------------------------------------------------------------------------------

func _build_nets() -> void:
	var shader: Shader = load(NET_SHADER)
	var mats: Dictionary = {}
	for kind: String in ["A", "B"]:
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("net_color", Color(0.9, 0.2, 0.1) if kind == "A" else Color(0.95, 0.55, 0.1))
		mats[kind] = m
	var post_xf: Array[Transform3D] = []
	for n: Dictionary in barriers.nets:
		var pts: PackedVector2Array = n["points"]
		var h: float = A_NET_H if n["kind"] == "A" else B_NET_H
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var along: float = 0.0
		var since_post: float = POST_SPACING
		for i in pts.size():
			var p: Vector2 = pts[i]
			if i > 0:
				var seg: float = p.distance_to(pts[i - 1])
				along += seg
				since_post += seg
			var y: float = _ground(p.x, p.y) - 0.2
			if since_post >= POST_SPACING:
				since_post = 0.0
				post_xf.append(Transform3D(Basis().scaled(Vector3(0.08, h + 0.3, 0.08)), Vector3(p.x, y + (h + 0.3) * 0.5, p.y)))
			if i == 0:
				continue
			var q: Vector2 = pts[i - 1]
			var yq: float = _ground(q.x, q.y) - 0.2
			var a0: float = along - p.distance_to(q)
			var v: Array[Vector3] = [Vector3(q.x, yq, q.y), Vector3(p.x, y, p.y), Vector3(p.x, y + h, p.y), Vector3(q.x, yq + h, q.y)]
			var uv: Array[Vector2] = [Vector2(a0, 0), Vector2(along, 0), Vector2(along, 1), Vector2(a0, 1)]
			var uv2: Array[Vector2] = [Vector2(a0, 0), Vector2(along, 0), Vector2(along, h), Vector2(a0, h)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[idx])
				st.set_uv2(uv2[idx])
				st.add_vertex(v[idx])
		st.generate_normals()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats[n["kind"]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Net%s" % n["kind"]
		add_child(mi)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm: BoxMesh = BoxMesh.new()
	bm.material = _mat(Color(0.25, 0.25, 0.28), 0.5)
	mm.mesh = bm
	mm.instance_count = post_xf.size()
	for i in post_xf.size():
		mm.set_instance_transform(i, post_xf[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "NetPosts"
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- gates --------------------------------------------------------------------------------

func rebuild_gates() -> void:
	for g: Node3D in gate_nodes:
		g.queue_free()
	gate_nodes.clear()
	for i in gates.gates.size():
		var g: Dictionary = gates.gates[i]
		var node: Node3D = Node3D.new()
		node.name = "Gate%d" % (i + 1)
		add_child(node)
		var col: Color = GATE_COLORS[i % 2]
		for key: String in ["left", "right"]:
			var p: Vector2 = g[key]
			node.add_child(_gate_side(p, col, g["left"] if key == "right" else g["right"]))
		gate_nodes.append(node)


## One side of a downhill gate: two poles with a fabric panel between them, facing the skier.
func _gate_side(p: Vector2, col: Color, other: Vector2) -> Node3D:
	var side: Node3D = Node3D.new()
	var across: Vector2 = (p - other).normalized()  # outward from the gate centre
	var base: Vector3 = Vector3(p.x, _ground(p.x, p.y), p.y)
	side.position = base
	var outer: Vector3 = Vector3(across.x, 0.0, across.y) * 0.75
	for off: Vector3 in [Vector3.ZERO, outer]:
		var pole: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.02
		cm.height = GATE_POLE_H
		cm.radial_segments = 6
		pole.mesh = cm
		pole.material_override = _mat(col.lightened(0.3), 0.4)
		pole.position = off + Vector3(0, GATE_POLE_H * 0.5, 0)
		side.add_child(pole)
	var panel: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.75, 0.75, 0.01)
	panel.mesh = bm
	panel.material_override = _mat(col, 0.9)
	panel.position = outer * 0.5 + Vector3(0, GATE_POLE_H - 0.55, 0)
	panel.rotation.y = atan2(-across.y, across.x)
	side.add_child(panel)
	return side


# --- start and finish ---------------------------------------------------------------------

func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot_y: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _build_start_house() -> void:
	var p: Vector3 = track.start_point()
	var d: Vector3 = track.direction_at(0.0)
	var yaw: float = atan2(-d.x, -d.z)
	var house: Node3D = Node3D.new()
	house.name = "StartHouse"
	house.position = Vector3(p.x, _ground(p.x, p.z), p.z) - d * 3.5
	house.rotation.y = yaw
	add_child(house)
	var wood: Color = Color(0.45, 0.3, 0.18)
	_box(house, Vector3(0.3, 3.2, 5.0), Vector3(-2.2, 1.6, 0), wood)
	_box(house, Vector3(0.3, 3.2, 5.0), Vector3(2.2, 1.6, 0), wood)
	_box(house, Vector3(4.7, 0.3, 5.0), Vector3(0, 3.35, 0), Color(0.3, 0.3, 0.32))
	_box(house, Vector3(4.7, 3.2, 0.3), Vector3(0, 1.6, 2.5), wood)
	_box(house, Vector3(4.5, 0.12, 1.0), Vector3(0, 0.06, -2.6), Color(0.85, 0.85, 0.9))  # start ramp
	_box(house, Vector3(2.0, 0.08, 0.08), Vector3(0, 0.6, -2.4), Color(0.9, 0.85, 0.1))  # start wand


func _build_finish() -> void:
	var s_f: float = gates.finish_s
	var p: Vector3 = track.point_at(s_f)
	var d: Vector3 = track.direction_at(s_f - 2.0)
	var right: Vector3 = Vector3(-d.z, 0.0, d.x)
	var w: float = RacingLine.width_at(track, s_f)
	var fin: Node3D = Node3D.new()
	fin.name = "Finish"
	add_child(fin)
	var yaw: float = atan2(right.x, right.z)
	# arch: two towers and a plain banner (no text, no marks)
	for sgn: float in [-1.0, 1.0]:
		var q: Vector3 = p + right * sgn * (w * 0.5 + 1.0)
		_box(fin, Vector3(1.2, 7.0, 1.2), Vector3(q.x, _ground(q.x, q.z) + 3.5, q.z), Color(0.2, 0.22, 0.28), yaw)
	var top: Vector3 = p
	_box(fin, Vector3(w + 3.2, 1.4, 0.4), Vector3(top.x, _ground(p.x, p.z) + 6.6, top.z), Color(0.85, 0.12, 0.12), yaw)
	# finish line painted on the snow
	for i in 12:
		var q: Vector3 = p + right * lerpf(-w * 0.5, w * 0.5, (float(i) + 0.5) / 12.0)
		_box(fin, Vector3(w / 12.0 * 0.9, 0.03, 0.5), Vector3(q.x, _ground(q.x, q.z) + 0.02, q.z), Color(0.8, 0.1, 0.1), yaw)
	# fences of the finish area (run-out)
	for sgn: float in [-1.0, 1.0]:
		var s: float = s_f - 60.0
		while s < s_f + 100.0:
			var c: Vector3 = track.point_at(minf(s, track.length())) if s <= track.length() else p + d * (s - s_f)
			var q: Vector3 = c + right * sgn * (w * 0.5 + 1.0)
			_box(fin, Vector3(0.1, 1.1, 4.0), Vector3(q.x, _ground(q.x, q.z) + 0.55, q.z), Color(0.9, 0.9, 0.92), atan2(d.x, d.z))
			s += 4.2
