class_name TreeMeshFactory
extends RefCounted
## Procedural low-poly conifer (own asset, no external model). Unit height 1 m, scaled per instance.

const TRUNK_COLOR: Color = Color(0.25, 0.17, 0.11)
const NEEDLE_DARK: Color = Color(0.03, 0.08, 0.045)
const NEEDLE_LIGHT: Color = Color(0.07, 0.14, 0.08)
const SNOW_TINT: Color = Color(0.82, 0.86, 0.9)


## lod 0: trunk + 3 stacked cones (8 sides); lod 1: one 5-sided cone.
static func conifer(lod: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if lod == 0:
		_cone(st, 0.0, 0.18, 0.035, 0.03, 6, TRUNK_COLOR, TRUNK_COLOR)
		_cone(st, 0.12, 0.55, 0.30, 0.0, 8, NEEDLE_DARK, NEEDLE_LIGHT.lerp(SNOW_TINT, 0.25))
		_cone(st, 0.38, 0.80, 0.22, 0.0, 8, NEEDLE_DARK, NEEDLE_LIGHT.lerp(SNOW_TINT, 0.35))
		_cone(st, 0.62, 1.00, 0.14, 0.0, 8, NEEDLE_DARK, NEEDLE_LIGHT.lerp(SNOW_TINT, 0.5))
	else:
		_cone(st, 0.08, 1.0, 0.28, 0.0, 5, NEEDLE_DARK, NEEDLE_LIGHT)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	return mesh


static func _cone(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, sides: int,
		c0: Color, c1: Color) -> void:
	for i in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var b0: Vector3 = Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var b1: Vector3 = Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var t0: Vector3 = Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var t1: Vector3 = Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		_tri(st, b0, t0, b1, c0, c1, c0)
		if r1 > 0.0:
			_tri(st, b1, t0, t1, c0, c1, c1)
		# underside of the cone skirt
		if r0 > 0.06:
			_tri(st, b0, b1, Vector3(0.0, y0 + 0.02, 0.0), c0, c0, c0)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## Scene usable as Terrain3DMeshAsset (children = LODs, highest detail first).
static func conifer_scene() -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "Conifer"
	for lod in 2:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "LOD%d" % lod
		mi.mesh = conifer(lod)
		root.add_child(mi)
		mi.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps
