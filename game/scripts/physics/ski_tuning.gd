class_name SkiTuning
extends Resource
## ALL handling values of the ski physics. Edited live in the F1 debug menu; presets as JSON.
## Every exported property with a range hint becomes a slider automatically (group = section).

@export_group("Körper & Luft")
@export_range(50.0, 150.0, 1.0, "suffix:kg") var mass: float = 95.0
@export_range(0.8, 1.3, 0.01, "suffix:kg/m³") var air_density: float = 1.05
@export_range(0.05, 0.6, 0.005, "suffix:m²") var cda_tuck: float = 0.22
@export_range(0.2, 1.2, 0.01, "suffix:m²") var cda_upright: float = 0.55
@export_range(0.3, 2.0, 0.01, "suffix:m²") var cda_brake: float = 0.95
@export_range(0.5, 10.0, 0.1, "suffix:1/s") var tuck_rate: float = 4.0
@export_range(0.0, 12.0, 0.1, "suffix:m/s") var start_speed: float = 6.0  ## skating out of the start gate

@export_group("Schnee & Reibung")
@export_range(0.0, 0.2, 0.001) var mu_glide: float = 0.022
@export_range(0.0, 1.5, 0.01) var mu_drift: float = 0.45
@export_range(0.0, 2.0, 0.01) var mu_brake: float = 0.35

@export_group("Kanten & Kurven")
@export_range(20.0, 80.0, 0.5, "suffix:m") var sidecut_radius: float = 50.0
@export_range(10.0, 80.0, 0.5, "suffix:°") var max_edge_angle: float = 62.0
@export_range(0.2, 1.0, 0.01) var tuck_edge_factor: float = 0.6
@export_range(20.0, 400.0, 1.0, "suffix:°/s") var edge_rate: float = 170.0
@export_range(0.5, 6.0, 0.05, "suffix:g") var edge_grip: float = 2.6
@export_range(0.0, 0.2, 0.005) var carve_drag: float = 0.02
@export_range(0.1, 5.0, 0.05, "suffix:rad/s") var pivot_rate: float = 1.8
@export_range(0.0, 3.0, 0.05, "suffix:rad/s") var min_steer_rate: float = 0.6
@export_range(0.0, 20.0, 0.5, "suffix:°") var edge_engage_start: float = 2.0  ## carving starts
@export_range(1.0, 40.0, 0.5, "suffix:°") var edge_engage_full: float = 15.0  ## carving fully engaged
@export_range(0.05, 1.0, 0.01) var brake_grip_factor: float = 0.35  ## edge grip while braking/skidding
@export_range(0.5, 20.0, 0.5, "suffix:1/s") var skid_rise_rate: float = 6.0  ## skid indicator dynamics
@export_range(0.5, 20.0, 0.5, "suffix:1/s") var skid_fall_rate: float = 4.0

@export_group("Sprung & Flug")
@export_range(0.0, 6.0, 0.1, "suffix:m/s") var prejump_impulse: float = 2.2
@export_range(0.1, 2.0, 0.05, "suffix:s") var prejump_cooldown: float = 0.8
@export_range(0.0, 0.2, 0.005, "suffix:m") var liftoff_clearance: float = 0.03
@export_range(0.0, 0.1, 0.001, "suffix:s") var liftoff_time: float = 0.016  ## gap must persist this long
@export_range(0.0, 0.5, 0.01, "suffix:s") var min_air_time: float = 0.1
@export_range(0.0, 3.0, 0.05, "suffix:rad/s") var air_yaw_rate: float = 0.7
@export_range(0.0, 10.0, 0.1, "suffix:1/s") var air_align_rate: float = 2.5  ## skis follow the flight path

@export_group("Sturz")
@export_range(0.5, 8.0, 0.1, "suffix:m") var landing_crash_drop: float = 2.5
@export_range(10.0, 90.0, 1.0, "suffix:°") var landing_crash_yaw: float = 45.0
@export_range(2.0, 10.0, 0.1, "suffix:g") var overload_crash_g: float = 4.5
@export_range(0.05, 1.0, 0.01, "suffix:s") var overload_time: float = 0.25
@export_range(0.1, 1.5, 0.05) var crash_friction: float = 0.6
@export_range(0.0, 10.0, 0.1, "suffix:rad/s") var crash_spin_rate: float = 2.0
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var landing_check_min_speed: float = 3.0
@export_range(2.0, 30.0, 0.5, "suffix:m/s") var net_crash_speed: float = 11.0  ## into a net/tree
@export_range(0.0, 1.0, 0.05) var net_restitution: float = 0.2
@export_range(0.0, 0.8, 0.01) var net_speed_loss: float = 0.15  ## fraction of speed lost per net contact
@export_range(0.0, 1.0, 0.05) var net_crash_keep: float = 0.4  ## speed fraction kept when crashing into a net
@export_range(0.01, 0.5, 0.01, "suffix:s") var g_filter_tau: float = 0.08  ## smoothing of the g-load


## All tunable property names (exported, numeric).
func tunable_properties() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in get_property_list():
		if (p["usage"] & PROPERTY_USAGE_EDITOR) and p["hint"] == PROPERTY_HINT_RANGE \
				and (p["type"] == TYPE_FLOAT or p["type"] == TYPE_INT):
			out.append(p)
	return out


func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for p: Dictionary in tunable_properties():
		d[p["name"]] = get(p["name"])
	return d


func apply_dict(d: Dictionary) -> void:
	for p: Dictionary in tunable_properties():
		var n: String = p["name"]
		if d.has(n):
			set(n, int(d[n]) if p["type"] == TYPE_INT else float(d[n]))


func save_json(path: String) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t", true))
	return OK


## Loads a preset (JSON only – never .tres from user://, which could carry scripts).
static func load_json(path: String) -> SkiTuning:
	var t: SkiTuning = SkiTuning.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		t.apply_dict(data)
	return t
