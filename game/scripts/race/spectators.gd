class_name Spectators
extends Node3D
## Crowd in the finish area: low-poly figures (MultiMesh), coloured jackets, cheering motion in
## the vertex shader (per-instance phase). Placed in rows behind the finish fences.

const ROWS: int = 4
const SPACING: float = 0.9
const SHADER: String = """shader_type spatial;
uniform float cheer = 0.0;
varying vec3 v_col;
void vertex() {
	float ph = INSTANCE_CUSTOM.r * 6.2831;
	float bob = sin(TIME * (2.0 + 4.0 * cheer) + ph) * (0.03 + 0.12 * cheer);
	// upper body sways more than the feet
	float h = clamp(VERTEX.y / 1.7, 0.0, 1.0);
	VERTEX.y += bob * h;
	VERTEX.x += sin(TIME * 1.3 + ph) * 0.05 * h;
	v_col = COLOR.rgb;
}
void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.8;
}
"""

var material: ShaderMaterial


func build(track: TrackData, finish_s: float, count: int = 360) -> void:
	material = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = SHADER
	material.shader = sh
	var body: CapsuleMesh = CapsuleMesh.new()
	body.radius = 0.22
	body.height = 1.45
	body.radial_segments = 6
	body.rings = 2
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.radial_segments = 6
	head.rings = 3
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var xf: Array[Transform3D] = []
	var hf: HeightField = track.height_field
	var p_f: Vector3 = track.point_at(finish_s)
	var d: Vector3 = track.direction_at(finish_s - 2.0)
	var right: Vector3 = Vector3(-d.z, 0.0, d.x)
	var half_w: float = RacingLine.width_at(track, finish_s) * 0.5 + 2.5
	var per_side: int = count / 2
	for sgn: float in [-1.0, 1.0]:
		for i in per_side:
			var row: int = i % ROWS
			var along: float = -50.0 + float(i / ROWS) * SPACING * 1.1 + rng.randf_range(-0.2, 0.2)
			var lat: float = half_w + float(row) * SPACING + rng.randf_range(-0.15, 0.15)
			var pos: Vector3 = p_f + d * along + right * sgn * lat
			pos.y = hf.height_at(pos.x, pos.z) + float(row) * 0.35  # stepped stands
			var b: Basis = Basis(Vector3.UP, atan2(right.x * -sgn, right.z * -sgn) + rng.randf_range(-0.4, 0.4))
			xf.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.9, 1.08)), pos))
	_add_mm(body, xf, Vector3(0, 0.72, 0), rng, true)
	_add_mm(head, xf, Vector3(0, 1.6, 0), rng, false)


func _add_mm(mesh: Mesh, xf: Array[Transform3D], offset: Vector3, rng: RandomNumberGenerator, jackets: bool) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	var palette: Array[Color] = [Color(0.85, 0.15, 0.12), Color(0.1, 0.3, 0.8), Color(0.95, 0.75, 0.1),
			Color(0.15, 0.6, 0.3), Color(0.2, 0.2, 0.25), Color(0.9, 0.9, 0.92), Color(0.6, 0.2, 0.6)]
	var r2: RandomNumberGenerator = RandomNumberGenerator.new()
	r2.seed = 7
	for i in xf.size():
		var t: Transform3D = xf[i]
		mm.set_instance_transform(i, Transform3D(t.basis, t.origin + t.basis * offset))
		var c: Color = palette[rng.randi() % palette.size()] if jackets else Color(0.85, 0.7, 0.6).darkened(rng.randf() * 0.3)
		mm.set_instance_color(i, c)
		mm.set_instance_custom_data(i, Color(r2.randf(), 0, 0, 0))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func set_cheer(amount: float) -> void:
	if material:
		material.set_shader_parameter("cheer", clampf(amount, 0.0, 1.0))
