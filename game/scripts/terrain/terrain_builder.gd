class_name TerrainBuilder
extends RefCounted
## Builds the Terrain3D node for a track at runtime from the pipeline output.

const TEXTURE_DIR: String = "res://assets/textures"
## Texture slots in the order of the control-map ids (meta.json "textures").
const SLOTS: Array[String] = ["snow", "piste", "forest", "rock"]
const FALLBACK_COLORS: Array[Color] = [
	Color(0.93, 0.95, 1.0), Color(0.86, 0.9, 0.97), Color(0.55, 0.58, 0.55), Color(0.5, 0.49, 0.47)]
const UV_SCALES: Array[float] = [0.08, 0.12, 0.1, 0.06]
const GLITTER_ANCHOR: String = "	SPECULAR = specular;\n"
const GLITTER_UNIFORMS: String = """uniform float snow_glint_density = 7.0;
uniform float snow_glint_strength = 2.2;
uniform float snow_glint_range = 70.0;

void fragment()"""
const GLITTER_CODE: String = """	// --- snow glitter (Schussfahrt) ---
	{
		vec3 sg_view = normalize(v_camera_pos - v_vertex);
		float sg_dist = length(v_camera_pos - v_vertex);
		vec2 sg_cell = floor(v_vertex.xz * snow_glint_density);
		float sg_h = fract(sin(dot(sg_cell, vec2(12.9898, 78.233))) * 43758.5453);
		vec3 sg_facet = normalize(vec3(fract(sg_h * 7.13) - 0.5, 1.2, fract(sg_h * 3.71) - 0.5));
		vec3 sg_half = normalize(normalize(_light_direction) + sg_view);
		float sg = step(0.97, sg_h) * smoothstep(0.985, 1.0, dot(sg_facet, sg_half));
		sg *= (1.0 - smoothstep(snow_glint_range * 0.5, snow_glint_range, sg_dist)) * terrain_facing_light;
		EMISSION = vec3(sg * snow_glint_strength);
	}
"""


static func build(track: TrackData, parent: Node, region_size: int = 1024) -> Terrain3D:
	var core: Dictionary = track.meta["core"]
	var w: int = int(core["width"])
	var d: int = int(core["height"])
	var t: Terrain3D = Terrain3D.new()
	t.name = "Terrain3D"
	t.free_editor_textures = false
	t.material = _material()
	t.assets = _assets()
	parent.add_child(t)
	t.change_region_size(region_size)  # only effective once the node is in the tree
	t.vertex_spacing = float(core["res_m"])
	t.collision_mode = 0  # physics uses HeightField, not Terrain3D collision
	t.mesh_lods = 7
	t.mesh_size = 48
	t.cast_shadows = RenderingServer.SHADOW_CASTING_SETTING_ON

	var height: Image = Image.create_from_data(w, d, false, Image.FORMAT_RF,
			FileAccess.get_file_as_bytes(track.dir.path_join(str(core["file"]))))
	var control: Image = Image.create_from_data(w, d, false, Image.FORMAT_RF,
			FileAccess.get_file_as_bytes(track.dir.path_join(str(track.meta["control"]["file"]))))
	var color: Image = Image.new()
	color.load_jpg_from_buffer(FileAccess.get_file_as_bytes(track.dir.path_join(str(track.meta["colormap"]["file"]))))
	color.convert(Image.FORMAT_RGBA8)
	_set_alpha(color, 0.5)  # alpha = roughness modifier, 0.5 = neutral
	t.data.import_images([height, control, color],
			Vector3(float(core["world_min_x"]), 0.0, float(core["world_min_z"])), 0.0, 1.0)
	t.data.calc_height_range(true)
	add_snow_glitter(t.material)
	return t


## Snow glitter (phase 6): Terrain3D generates its shader at runtime; we take that code as an
## override and add sparkling ice crystals (world-space hash, view/light dependent, near camera).
## Falls back to the stock shader if the injection anchor is not found (future Terrain3D versions).
static func add_snow_glitter(m: Terrain3DMaterial) -> bool:
	m.shader_override_enabled = true
	var base: Shader = m.shader_override
	if base == null or not base.code.contains(GLITTER_ANCHOR):
		m.shader_override_enabled = false
		push_warning("TerrainBuilder: snow glitter anchor not found, using the stock terrain shader")
		return false
	var code: String = base.code.replace(GLITTER_ANCHOR, GLITTER_ANCHOR + GLITTER_CODE)
	code = code.replace("void fragment()", GLITTER_UNIFORMS)  # uniforms right before fragment()
	var sh: Shader = Shader.new()
	sh.code = code
	m.shader_override = sh
	return true


static func _set_alpha(img: Image, a: float) -> void:
	var data: PackedByteArray = img.get_data()
	var v: int = int(round(a * 255.0))
	for i in range(3, data.size(), 4):
		data[i] = v
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


static func _material() -> Terrain3DMaterial:
	var m: Terrain3DMaterial = Terrain3DMaterial.new()
	m.auto_shader_enabled = false
	m.world_background = 0  # NONE: the far-ring mesh covers the outside
	m.set_shader_param("blend_sharpness", 0.75)
	return m


static func _assets() -> Terrain3DAssets:
	var a: Terrain3DAssets = Terrain3DAssets.new()
	for i in SLOTS.size():
		var ta: Terrain3DTextureAsset = Terrain3DTextureAsset.new()
		ta.name = SLOTS[i]
		ta.id = i
		var alb_path: String = "%s/%s_albedo_height.png" % [TEXTURE_DIR, SLOTS[i]]
		var nor_path: String = "%s/%s_normal_rough.png" % [TEXTURE_DIR, SLOTS[i]]
		if ResourceLoader.exists(alb_path) and ResourceLoader.exists(nor_path):
			ta.albedo_texture = load(alb_path)
			ta.normal_texture = load(nor_path)
			ta.uv_scale = UV_SCALES[i]
		else:
			ta.albedo_color = FALLBACK_COLORS[i]
		a.set_texture_asset(i, ta)
	return a


## Places tree instances (trees.bin) through Terrain3D's instancer (LOD + chunked MultiMeshes).
static func add_trees(t: Terrain3D, track: TrackData, density: float = 1.0, view_distance: float = 1.0) -> int:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(track.dir.path_join("trees.bin"))
	var vals: PackedFloat32Array = bytes.to_float32_array()
	var ma: Terrain3DMeshAsset = Terrain3DMeshAsset.new()
	ma.name = "conifer"
	ma.scene_file = TreeMeshFactory.conifer_scene()
	ma.lod0_range = 180.0
	ma.lod1_range = 2500.0 * view_distance
	ma.last_shadow_lod = 0
	ma.cast_shadows = RenderingServer.SHADOW_CASTING_SETTING_ON
	t.assets.set_mesh_asset(0, ma)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4711
	var xforms: Array[Transform3D] = []
	var colors: PackedColorArray = PackedColorArray()
	var hf: HeightField = track.height_field
	for i in range(0, vals.size(), 3):
		if density < 1.0 and rng.randf() > density:
			continue
		var x: float = vals[i]
		var z: float = vals[i + 1]
		var h: float = vals[i + 2]
		# mesh crown diameter is 0.6 at unit height; spruce crowns are ~0.3 x height
		var width: float = h * 0.5 * rng.randf_range(0.8, 1.2)
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, h, width))
		xforms.append(Transform3D(basis, Vector3(x, hf.height_at(x, z) - 0.4, z)))
		colors.append(Color(1, 1, 1).darkened(rng.randf() * 0.25))
	t.instancer.add_transforms(0, xforms, colors, true)
	return xforms.size()
