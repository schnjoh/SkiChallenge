class_name RingTerrain
extends RefCounted
## Low-resolution terrain rings around the playable core (far: 4 m data, horizon: 32 m data).
## Chunked ArrayMeshes; vertices inside the inner hole sink below the inner terrain (skirt),
## cells completely inside the hole or touching invalid data (outside Tyrol) are dropped.

const SHADER_PATH: String = "res://scripts/terrain/ring_terrain.gdshader"
const SINK_M: float = 8.0


## ``steps`` = sample stride per LOD; ``lod_ranges`` = visibility end of each LOD but the last.
static func build(track: TrackData, parent: Node3D, ring: String, inner: Dictionary,
		chunk_samples: int, steps: Array[int], lod_ranges: Array[float]) -> Node3D:
	var g: Dictionary = track.meta[ring]
	var w: int = int(g["width"])
	var d: int = int(g["height"])
	var res: float = float(g["res_m"])
	var min_x: float = float(g["world_min_x"])
	var min_z: float = float(g["world_min_z"])
	var h: PackedFloat32Array = FileAccess.get_file_as_bytes(track.dir.path_join(str(g["file"]))).to_float32_array()
	var valid: Image = _load_image(track.dir.path_join(str(g["valid"])))
	var valid_bytes: PackedByteArray = valid.get_data() if valid else PackedByteArray()
	var color: Image = _load_image(track.dir.path_join(str(g["color"])))
	color.generate_mipmaps()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("color_map", ImageTexture.create_from_image(color))
	mat.set_shader_parameter("map_min", Vector2(min_x, min_z))
	mat.set_shader_parameter("map_size", Vector2((w - 1) * res, (d - 1) * res))
	# inner hole in world coordinates
	var hole_min: Vector2 = Vector2(float(inner["world_min_x"]), float(inner["world_min_z"]))
	var hole_max: Vector2 = hole_min + Vector2((float(inner["width"]) - 1.0) * float(inner["res_m"]),
			(float(inner["height"]) - 1.0) * float(inner["res_m"]))
	var root: Node3D = Node3D.new()
	root.name = "Ring_" + ring
	parent.add_child(root)
	var ctx: Dictionary = {"h": h, "w": w, "d": d, "res": res, "min_x": min_x, "min_z": min_z,
			"valid": valid_bytes, "hole_min": hole_min, "hole_max": hole_max}
	for c0 in range(0, d - 1, chunk_samples):
		for c1 in range(0, w - 1, chunk_samples):
			var r_end: int = mini(c0 + chunk_samples, d - 1)
			var c_end: int = mini(c1 + chunk_samples, w - 1)
			var cmin: Vector2 = Vector2(min_x + c1 * res, min_z + c0 * res)
			var cmax: Vector2 = Vector2(min_x + c_end * res, min_z + r_end * res)
			var margin: float = float(steps[steps.size() - 1]) * res
			if cmin.x >= hole_min.x + margin and cmin.y >= hole_min.y + margin \
					and cmax.x <= hole_max.x - margin and cmax.y <= hole_max.y - margin:
				continue
			for lod in steps.size():
				var mesh: ArrayMesh = _chunk(ctx, c1, c0, c_end, r_end, steps[lod])
				if mesh.get_surface_count() == 0:
					continue
				var mi: MeshInstance3D = MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if lod > 0:
					mi.visibility_range_begin = lod_ranges[lod - 1]
				if lod < lod_ranges.size():
					mi.visibility_range_end = lod_ranges[lod]
				root.add_child(mi)
	return root


static func _load_image(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img: Image = Image.new()
	var err: Error = img.load_jpg_from_buffer(bytes) if path.ends_with(".jpg") else img.load_png_from_buffer(bytes)
	return img if err == OK else null


static func _chunk(ctx: Dictionary, c0: int, r0: int, c1: int, r1: int, step: int) -> ArrayMesh:
	var h: PackedFloat32Array = ctx["h"]
	var w: int = ctx["w"]
	var d: int = ctx["d"]
	var res: float = ctx["res"]
	var min_x: float = ctx["min_x"]
	var min_z: float = ctx["min_z"]
	var valid: PackedByteArray = ctx["valid"]
	var hole_min: Vector2 = ctx["hole_min"]
	var hole_max: Vector2 = ctx["hole_max"]
	var cols: Array[int] = _samples(c0, c1, step)
	var rows: Array[int] = _samples(r0, r1, step)
	var nx: int = cols.size()
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var inside: PackedByteArray = PackedByteArray()
	var ok: PackedByteArray = PackedByteArray()
	var n: int = nx * rows.size()
	verts.resize(n)
	normals.resize(n)
	inside.resize(n)
	ok.resize(n)
	var k: int = 0
	for r: int in rows:
		for c: int in cols:
			var x: float = min_x + c * res
			var z: float = min_z + r * res
			var y: float = h[r * w + c]
			var in_hole: bool = x > hole_min.x + res and z > hole_min.y + res \
					and x < hole_max.x - res and z < hole_max.y - res
			if in_hole:
				y -= SINK_M
			verts[k] = Vector3(x, y, z)
			var cl: int = maxi(c - step, 0)
			var cr: int = mini(c + step, w - 1)
			var ru: int = maxi(r - step, 0)
			var rd: int = mini(r + step, d - 1)
			var dx: float = (h[r * w + cr] - h[r * w + cl]) / (float(cr - cl) * res)
			var dz: float = (h[rd * w + c] - h[ru * w + c]) / (float(rd - ru) * res)
			normals[k] = Vector3(-dx, 1.0, -dz).normalized()
			inside[k] = 1 if in_hole else 0
			ok[k] = 1 if valid.is_empty() or valid[r * w + c] > 127 else 0
			k += 1
	var idx: PackedInt32Array = PackedInt32Array()
	for j in rows.size() - 1:
		for i in nx - 1:
			var a: int = j * nx + i
			var b: int = a + 1
			var c: int = a + nx
			var e: int = c + 1
			if inside[a] + inside[b] + inside[c] + inside[e] == 4:
				continue
			if ok[a] + ok[b] + ok[c] + ok[e] < 4:
				continue
			idx.append_array([a, b, e, a, e, c])
	var mesh: ArrayMesh = ArrayMesh.new()
	if idx.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _samples(a: int, b: int, step: int) -> Array[int]:
	var out: Array[int] = []
	var i: int = a
	while i < b:
		out.append(i)
		i += step
	out.append(b)
	return out
