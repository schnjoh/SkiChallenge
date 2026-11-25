class_name World
extends Node3D
## Builds the playable world of a track at runtime: environment, Terrain3D, trees, far ring.

signal built

@export var track_dir: String = TrackData.DEFAULT_DIR
@export_range(0.0, 1.0) var tree_density: float = 1.0
@export var build_on_ready: bool = true
@export var shadows: bool = true
@export var rings: bool = true
@export_range(0.3, 1.0) var view_distance: float = 1.0  ## scales fog, tree LOD and far-ring detail

var track: TrackData
var terrain: Terrain3D
var sun: DirectionalLight3D
var environment: Environment
var tree_count: int = 0


func _ready() -> void:
	if build_on_ready:
		build()


func build() -> void:
	var t0: int = Time.get_ticks_msec()
	track = TrackData.load_track(track_dir)
	if track == null:
		push_error("World: track could not be loaded")
		return
	_build_environment()
	terrain = TerrainBuilder.build(track, self)
	terrain.set_clipmap_target(self)  # until a camera is assigned (avoids Terrain3D camera errors)
	if tree_density > 0.0:
		tree_count = TerrainBuilder.add_trees(terrain, track, tree_density, view_distance)
	if rings:
		RingTerrain.build(track, self, "far", track.meta["core"], 256, [2, 8] as Array[int], [2500.0] as Array[float])
		RingTerrain.build(track, self, "horizon", track.meta["far"], 116, [1] as Array[int], [] as Array[float])
	print("World built in %d ms (%d trees)" % [Time.get_ticks_msec() - t0, tree_count])
	built.emit()


## Terrain3D clipmap and instancer follow this camera.
func set_camera(cam: Camera3D) -> void:
	if terrain:
		terrain.set_camera(cam)
		terrain.set_clipmap_target(cam)


func _build_environment() -> void:
	environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_mat: ShaderMaterial = ShaderMaterial.new()
	sky_mat.shader = load("res://scripts/terrain/sky.gdshader")
	sky_mat.set_shader_parameter("panorama", load("res://assets/hdri/sky_2k.hdr"))
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 0.9
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.00011 / clampf(view_distance, 0.3, 1.0)
	environment.fog_light_color = Color(0.78, 0.84, 0.93)
	environment.fog_aerial_perspective = 0.6
	environment.fog_sky_affect = 0.15
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	# winter sun: south-west, ~28 deg elevation
	sun.rotation_degrees = Vector3(-28.0, 200.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = shadows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)
