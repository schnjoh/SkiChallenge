extends Node
## Autoload "Session": selected mode and persistent settings (user://settings.json).

enum Mode { RACE, TRAINING }

const SETTINGS_PATH: String = "user://settings.json"
const DEFAULTS: Dictionary = {
	"player_name": "Fahrer",
	"render_scale": 0.8,  ## 3D resolution scale (FSR 1 below 1.0)
	"fsr": true,
	"view_distance": 0.7,  ## 0.4..1.0, scales fog/far ring/tree LOD distances
	"tree_density": 0.5,
	"shadows": 1,  ## 0 off, 1 medium, 2 high
	"msaa": 0,  ## 0 off, 1 2x, 2 4x
	"vsync": true,
	"fullscreen": false,
	"master_volume": 0.8,
	"ghost": true,
	"camera": 0,  ## 0 chase, 1 helmet
}

var mode: Mode = Mode.RACE
var settings: Dictionary = DEFAULTS.duplicate()
var training_section: String = "Start"


func _ready() -> void:
	load_settings()
	apply_window_settings()


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULTS.get(key))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value


func load_settings() -> void:
	settings = DEFAULTS.duplicate()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if data is Dictionary:
		for k: String in DEFAULTS:
			if (data as Dictionary).has(k):
				settings[k] = typeof_like(DEFAULTS[k], (data as Dictionary)[k])


static func typeof_like(template: Variant, v: Variant) -> Variant:
	match typeof(template):
		TYPE_BOOL:
			return bool(v)
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
		_:
			return str(v)


func save_settings() -> void:
	var f: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))


func apply_window_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_setting("vsync") else DisplayServer.VSYNC_DISABLED)
	var want_fs: bool = get_setting("fullscreen")
	var is_fs: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if want_fs != is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(get_setting("master_volume")), 0.0001)))


## Applies the 3D quality settings to a viewport (render scale, FSR, MSAA).
func apply_viewport_settings(vp: Viewport) -> void:
	var scale: float = clampf(float(get_setting("render_scale")), 0.5, 1.0)
	vp.scaling_3d_scale = scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (bool(get_setting("fsr")) and scale < 0.99) else Viewport.SCALING_3D_MODE_BILINEAR
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(int(get_setting("msaa")), 0, 2)]
