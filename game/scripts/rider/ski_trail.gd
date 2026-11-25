class_name SkiTrail
extends MeshInstance3D
## Ski tracks in the snow: two grooves behind the rider while on the ground (ring buffer, fading).

const SPACING: float = 0.6  ## m between samples
const MAX_SAMPLES: int = 700  ## ~420 m of track
const HALF_GAP: float = 0.13  ## half distance between the skis
const WIDTH: float = 0.07
const LIFT: float = 0.025

var rider: Rider
var _pts: Array[Dictionary] = []  ## {p: Vector3, right: Vector3, strength: float, break: bool}
var _mat: StandardMaterial3D
var _was_ground: bool = false


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.35
	_mat.albedo_color = Color(0.72, 0.78, 0.9)
	top_level = true


func clear() -> void:
	_pts.clear()
	mesh = null


func _process(_dt: float) -> void:
	if rider == null or rider.physics == null:
		return
	var ph: SkiPhysics = rider.physics
	var ground: bool = not ph.is_airborne() and not ph.is_crashed() and ph.speed() > 1.0
	if ground:
		var p: Vector3 = rider.global_position
		if _pts.is_empty() or not _was_ground or (_pts[_pts.size() - 1]["p"] as Vector3).distance_to(p) >= SPACING:
			var right: Vector3 = ph.heading().cross(ph.surface_normal).normalized()
			_pts.append({"p": p + ph.surface_normal * LIFT, "right": right,
					"strength": clampf(0.35 + ph.skid * 0.6 + absf(ph.edge_angle) / 120.0, 0.0, 1.0),
					"break": not _was_ground})
			if _pts.size() > MAX_SAMPLES:
				_pts.pop_front()
			_rebuild()
	_was_ground = ground


func _rebuild() -> void:
	if _pts.size() < 2:
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_mat)
	var n: int = _pts.size()
	for ski: float in [-1.0, 1.0]:
		for i in range(1, n):
			var a: Dictionary = _pts[i - 1]
			var b: Dictionary = _pts[i]
			if b["break"]:
				continue
			var fa: float = float(i - 1) / float(n) * float(a["strength"]) * 0.55
			var fb: float = float(i) / float(n) * float(b["strength"]) * 0.55
			var ca: Vector3 = (a["p"] as Vector3) + (a["right"] as Vector3) * ski * HALF_GAP
			var cb: Vector3 = (b["p"] as Vector3) + (b["right"] as Vector3) * ski * HALF_GAP
			var wa: Vector3 = (a["right"] as Vector3) * WIDTH
			var wb: Vector3 = (b["right"] as Vector3) * WIDTH
			var col_a: Color = Color(0.62, 0.68, 0.8, fa)
			var col_b: Color = Color(0.62, 0.68, 0.8, fb)
			for v: Array in [[ca - wa, col_a], [cb - wb, col_b], [cb + wb, col_b], [ca - wa, col_a], [cb + wb, col_b], [ca + wa, col_a]]:
				st.set_color(v[1])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	mesh = st.commit()
