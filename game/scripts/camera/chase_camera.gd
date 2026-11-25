class_name ChaseCamera
extends Camera3D
## Chase camera behind/above the rider (FOV grows with speed, slight shake) or helmet camera.

enum Mode { CHASE, HELMET }

@export var distance: float = 4.5
@export var height: float = 1.8
@export var look_ahead: float = 6.0
@export var fov_slow: float = 70.0
@export var fov_fast: float = 90.0
@export var fov_full_kmh: float = 150.0
@export var follow_rate: float = 6.0  ## 1/s, exponential damping of the camera position
@export var shake_from_kmh: float = 100.0
@export var shake_amount: float = 0.03

var rider: Rider
var mode: Mode = Mode.CHASE
var _dir: Vector3 = Vector3.FORWARD
var _shake_t: float = 0.0
var _impact: float = 0.0
var _last_landings: int = 0


func _ready() -> void:
	near = 0.1
	far = 20000.0
	fov = fov_slow


func toggle_mode() -> void:
	mode = Mode.HELMET if mode == Mode.CHASE else Mode.CHASE
	if rider:
		rider.visual.visible = mode == Mode.CHASE


func snap() -> void:
	if rider == null:
		return
	_dir = rider.physics.heading()
	_update(1.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		toggle_mode()


func _process(dt: float) -> void:
	if rider and rider.physics:
		_update(dt, false)


func _update(dt: float, instant: bool) -> void:
	var phys: SkiPhysics = rider.physics
	var v: Vector3 = phys.vel
	v.y = 0.0
	var want_dir: Vector3 = v.normalized() if v.length() > 2.0 else phys.heading()
	if phys.is_crashed() and v.length() < 2.0:
		want_dir = _dir
	var k: float = 1.0 if instant else clampf(dt * 4.0, 0.0, 1.0)
	_dir = _dir.slerp(want_dir, k).normalized() if _dir.dot(want_dir) > -0.99 else want_dir
	var kmh: float = phys.speed_kmh()
	fov = lerpf(fov, lerpf(fov_slow, fov_fast, clampf(kmh / fov_full_kmh, 0.0, 1.0)), 1.0 if instant else k)
	if phys.landings != _last_landings:
		_last_landings = phys.landings
		_impact = clampf(phys.last_landing_drop / 2.0, 0.0, 1.0)
	_impact = move_toward(_impact, 0.0, dt * 2.0)
	_shake_t += dt
	var shake_amp: float = shake_amount * clampf((kmh - shake_from_kmh) / 50.0, 0.0, 1.0) + _impact * 0.12
	var shake: Vector3 = Vector3(sin(_shake_t * 37.0), sin(_shake_t * 43.0 + 1.3), 0.0) * shake_amp
	var target: Vector3 = rider.global_position
	if mode == Mode.HELMET:
		global_position = rider.visual.head_position() + shake * 0.5
		look_at(global_position + phys.heading() * 10.0 + Vector3(0, -1.2, 0), Vector3.UP)
		return
	var hf: HeightField = phys.surface
	var want_pos: Vector3 = target - _dir * distance + Vector3.UP * height
	var ground: float = hf.height_at(want_pos.x, want_pos.z) + 0.8
	want_pos.y = maxf(want_pos.y, ground)
	var kp: float = 1.0 if instant else clampf(dt * follow_rate, 0.0, 1.0)
	global_position = global_position.lerp(want_pos, kp) if not instant else want_pos
	# keep the distance bounded (fast rider would outrun the damped camera)
	var off: Vector3 = global_position - target
	if off.length() > distance * 1.6:
		global_position = target + off.normalized() * distance * 1.6
	global_position.y = maxf(global_position.y, hf.height_at(global_position.x, global_position.z) + 0.5)
	look_at(target + _dir * look_ahead + Vector3(0, 0.6, 0) + shake, Vector3.UP)
