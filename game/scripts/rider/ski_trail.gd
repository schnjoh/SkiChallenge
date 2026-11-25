class_name SkiTrail
extends Node3D
## Ski tracks in the snow: two grooves behind the rider while on the ground. Built in chunks of
## CHUNK samples; only the newest chunk is regenerated, so the cost per frame stays constant.

const SPACING: float = 0.6  ## m between samples
const CHUNK: int = 24
const MAX_CHUNKS: int = 24  ## ~350 m of track
const HALF_GAP: float = 0.13  ## half distance between the skis
const WIDTH: float = 0.07
const LIFT: float = 0.025

var rider: Rider
var _cur: Array[Dictionary] = []  ## samples of the open chunk {p, right, a}
var _chunks: Array[MeshInstance3D] = []
var _open: MeshInstance3D
var _mat: StandardMaterial3D
var _was_ground: bool = false


func _ready() -> void:
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.35


func clear() -> void:
	for c: MeshInstance3D in _chunks:
		c.queue_free()
	_chunks.clear()
	_cur.clear()
	_open = null


func _process(_dt: float) -> void:
	if rider == null or rider.physics == null:
		return
	var ph: SkiPhysics = rider.physics
	var ground: bool = not ph.is_airborne() and not ph.is_crashed() and ph.speed() > 1.0
	if not ground:
		if _was_ground:
			_close_chunk()
		_was_ground = false
		return
	var p: Vector3 = rider.global_position
	if _cur.is_empty() or (_cur[_cur.size() - 1]["p"] as Vector3).distance_to(p) >= SPACING:
		_cur.append({"p": p + ph.surface_normal * LIFT, "right": ph.heading().cross(ph.surface_normal).normalized(),
				"a": clampf(0.25 + ph.skid * 0.5 + absf(ph.edge_angle) / 140.0, 0.0, 0.7)})
		_rebuild_open()
		if _cur.size() >= CHUNK:
			_close_chunk()
			_cur.append(_last)  # continue seamlessly
	_was_ground = true


var _last: Dictionary = {}


func _close_chunk() -> void:
	if _cur.size() > 0:
		_last = _cur[_cur.size() - 1]
	_open = null
	_cur.clear()
	while _chunks.size() > MAX_CHUNKS:
		_chunks.pop_front().queue_free()


func _rebuild_open() -> void:
	if _cur.size() < 2:
		return
	if _open == null:
		_open = MeshInstance3D.new()
		_open.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_open)
		_chunks.append(_open)
	var verts: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	for ski: float in [-1.0, 1.0]:
		for i in range(1, _cur.size()):
			var a: Dictionary = _cur[i - 1]
			var b: Dictionary = _cur[i]
			var ra: Vector3 = a["right"]
			var rb: Vector3 = b["right"]
			var ca: Vector3 = (a["p"] as Vector3) + ra * ski * HALF_GAP
			var cb: Vector3 = (b["p"] as Vector3) + rb * ski * HALF_GAP
			var col_a: Color = Color(0.62, 0.68, 0.8, a["a"])
			var col_b: Color = Color(0.62, 0.68, 0.8, b["a"])
			verts.append_array([ca - ra * WIDTH, cb - rb * WIDTH, cb + rb * WIDTH, ca - ra * WIDTH, cb + rb * WIDTH, ca + ra * WIDTH])
			cols.append_array([col_a, col_b, col_b, col_a, col_b, col_a])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(0, _mat)
	_open.mesh = am
