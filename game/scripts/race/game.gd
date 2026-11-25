class_name Game
extends Node3D
## Playable session: world, rider, camera, debug menus. Thin node layer over pure logic classes.

const TUNING_PATH: String = "res://resources/ski_tuning.tres"

var world: World
var rider: Rider
var cam: ChaseCamera
var tuning_menu: TuningMenu
var tuning: SkiTuning
var info: Label
var bot: BotDriver


func _ready() -> void:
	tuning = (load(TUNING_PATH) as SkiTuning).duplicate()
	world = World.new()
	add_child(world)
	rider = Rider.new()
	rider.name = "Rider"
	add_child(rider)
	var track: TrackData = world.track
	rider.setup(track.height_field, track.start_point(), SkiPhysics.dir_to_yaw(track.direction_at(0.0)), tuning)
	cam = ChaseCamera.new()
	cam.rider = rider
	add_child(cam)
	cam.make_current()
	world.set_camera(cam)
	cam.snap()
	rider.restarted.connect(cam.snap)
	tuning_menu = TuningMenu.new(tuning)
	add_child(tuning_menu)
	var hud: CanvasLayer = CanvasLayer.new()
	add_child(hud)
	info = Label.new()
	info.position = Vector2(1500, 20)
	info.add_theme_font_size_override("font_size", 22)
	hud.add_child(info)


## Lets the validation bot drive (demo / screenshots).
func enable_bot() -> void:
	bot = BotDriver.new(TrackPath.from_points(world.track.line_points))
	rider.autopilot = bot.drive


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		rider.restart()


func _process(_dt: float) -> void:
	var p: SkiPhysics = rider.physics
	info.text = "%3.0f km/h\n%.1f s\n%s" % [p.speed_kmh(), p.time, p.crash_reason]
