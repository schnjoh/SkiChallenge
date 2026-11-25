class_name Rider
extends Node3D
## Node adapter around SkiPhysics: fixed-step physics, device input, restart, visual sync.
## Rendering interpolates between the last two physics states (physics 120 Hz, render 60+ Hz).

signal crashed(reason: String)
signal restarted
signal stepped(input: SkiInput, prev_pos: Vector3)  ## after every physics step

var tuning: SkiTuning
var physics: SkiPhysics
var barriers: CourseBarriers  ## optional: nets and trees
var last_contact: String = ""
var visual: RiderVisual
var autopilot: Callable = Callable()  ## optional: func(physics) -> SkiInput (bot / demo)
var controls_enabled: bool = true
var frozen: bool = false  ## e.g. before the start or after the finish
var start_pos: Vector3
var start_yaw: float
var last_input: SkiInput = SkiInput.new()
var _prejump_latch: bool = false
var _was_crashed: bool = false
var _prev_pos: Vector3
var _cur_pos: Vector3


func setup(surface: HeightField, p_start: Vector3, p_yaw: float, p_tuning: SkiTuning) -> void:
	tuning = p_tuning
	physics = SkiPhysics.new(tuning, surface)
	start_pos = p_start
	start_yaw = p_yaw
	if visual == null:
		visual = RiderVisual.new()
		add_child(visual)
	restart()


func restart(at_pos: Vector3 = start_pos, at_yaw: float = start_yaw, speed: float = -1.0) -> void:
	physics.reset(at_pos, at_yaw, tuning.start_speed if speed < 0.0 else speed)
	_was_crashed = false
	_prev_pos = physics.pos
	_cur_pos = physics.pos
	global_position = physics.pos
	visual.apply_pose(physics, 1.0)
	restarted.emit()


func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and event.is_action_pressed("prejump"):
		_prejump_latch = true


func _physics_process(dt: float) -> void:
	if physics == null or frozen:
		return
	var input: SkiInput
	if autopilot.is_valid():
		input = autopilot.call(physics)
	elif controls_enabled and not get_viewport().gui_get_focus_owner() is LineEdit:
		input = GameInput.read(_prejump_latch)
	else:
		input = SkiInput.make(0.0, false, true)
	_prejump_latch = false
	last_input = input
	_prev_pos = physics.pos
	physics.step(input, dt)
	if barriers:
		last_contact = barriers.resolve(physics, _prev_pos)
	_cur_pos = physics.pos
	stepped.emit(input, _prev_pos)
	if physics.is_crashed() and not _was_crashed:
		_was_crashed = true
		crashed.emit(physics.crash_reason)


## Shows an externally given state (replay). Physics must be frozen.
func display_state(proxy: SkiPhysics) -> void:
	physics.pos = proxy.pos
	physics.vel = proxy.vel
	physics.yaw = proxy.yaw
	physics.tuck_amount = proxy.tuck_amount
	physics.edge_angle = proxy.edge_angle
	physics.phase = proxy.phase
	physics.surface_normal = proxy.surface_normal
	_prev_pos = proxy.pos
	_cur_pos = proxy.pos


func _process(dt: float) -> void:
	if physics == null:
		return
	var f: float = Engine.get_physics_interpolation_fraction() if not frozen else 1.0
	global_position = _prev_pos.lerp(_cur_pos, f)
	visual.apply_pose(physics, dt)
