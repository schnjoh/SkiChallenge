class_name RiderVisual
extends Node3D
## Low-poly rider built from primitives with code-driven poses (tuck, upright, lean, flight, crash).
## Interface: apply_pose(physics) - a rigged model can replace this class with the same method.

const THIGH: float = 0.46
const SHIN: float = 0.46
const ANKLE_H: float = 0.14
const TORSO: float = 0.62
const UPPER_ARM: float = 0.3
const FOREARM: float = 0.3
const SKI_LEN: float = 2.15
const STANCE: float = 0.14  ## half distance between the feet

const SUIT: Color = Color(0.85, 0.16, 0.12)
const SUIT_DARK: Color = Color(0.12, 0.13, 0.18)
const HELMET: Color = Color(0.95, 0.95, 0.97)
const SKI: Color = Color(0.1, 0.35, 0.85)
const POLE: Color = Color(0.75, 0.75, 0.78)

var body: Node3D  ## whole rider, lean + crash rotation
var pelvis: Node3D
var torso: Node3D
var head: Node3D
var legs: Array[Dictionary] = []  ## {hip, knee, foot, ski}
var arms: Array[Dictionary] = []  ## {shoulder, elbow, pole}
var _tuck: float = 0.0
var _lean: float = 0.0
var _crash_t: float = 0.0
var _crash_spin: Vector3 = Vector3.ZERO
var _mats: Dictionary = {}
var ghost: bool = false  ## translucent ghost rider (best run)


func _init(p_ghost: bool = false) -> void:
	ghost = p_ghost
	name = "GhostVisual" if ghost else "RiderVisual"
	body = Node3D.new()
	add_child(body)
	for side: float in [-1.0, 1.0]:
		var hip: Node3D = _joint(body)
		_part(hip, Vector3(0.16, THIGH, 0.17), Vector3(0, -THIGH / 2.0, 0), SUIT)
		var knee: Node3D = _joint(hip, Vector3(0, -THIGH, 0))
		_part(knee, Vector3(0.13, SHIN, 0.14), Vector3(0, -SHIN / 2.0, 0), SUIT)
		var foot: Node3D = _joint(body)
		_part(foot, Vector3(0.13, 0.17, 0.32), Vector3(0, 0.08, 0.02), SUIT_DARK)  # boot
		var ski: Node3D = _joint(foot)
		_part(ski, Vector3(0.075, 0.025, SKI_LEN), Vector3(0, 0.012, 0.0), SKI)
		_part(ski, Vector3(0.075, 0.025, 0.18), Vector3(0, 0.05, -SKI_LEN / 2.0 + 0.02), SKI, Vector3(-35, 0, 0))
		legs.append({"side": side, "hip": hip, "knee": knee, "foot": foot, "ski": ski})
	pelvis = _joint(body)
	_part(pelvis, Vector3(0.36, 0.2, 0.24), Vector3.ZERO, SUIT_DARK)
	torso = _joint(pelvis, Vector3(0, 0.06, 0))
	_part(torso, Vector3(0.4, TORSO, 0.26), Vector3(0, TORSO / 2.0, 0), SUIT)
	_part(torso, Vector3(0.3, 0.12, 0.2), Vector3(0, TORSO * 0.55, -0.12), Color(1, 1, 1))  # bib
	head = _joint(torso, Vector3(0, TORSO + 0.05, 0))
	var helmet: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	sm.radial_segments = 12
	sm.rings = 6
	helmet.mesh = sm
	helmet.material_override = _mat(HELMET)
	helmet.position = Vector3(0, 0.14, 0)
	head.add_child(helmet)
	_part(head, Vector3(0.22, 0.07, 0.06), Vector3(0, 0.15, -0.14), Color(0.9, 0.55, 0.1))  # goggles
	for side: float in [-1.0, 1.0]:
		var shoulder: Node3D = _joint(torso, Vector3(side * 0.25, TORSO - 0.05, 0))
		_part(shoulder, Vector3(0.11, UPPER_ARM, 0.11), Vector3(0, -UPPER_ARM / 2.0, 0), SUIT)
		var elbow: Node3D = _joint(shoulder, Vector3(0, -UPPER_ARM, 0))
		_part(elbow, Vector3(0.09, FOREARM, 0.09), Vector3(0, -FOREARM / 2.0, 0), SUIT)
		_part(elbow, Vector3(0.1, 0.1, 0.1), Vector3(0, -FOREARM, 0), SUIT_DARK)  # glove
		var pole: Node3D = _joint(elbow, Vector3(0, -FOREARM, 0))
		_part(pole, Vector3(0.022, 1.2, 0.022), Vector3(0, -0.45, 0), POLE)
		arms.append({"side": side, "shoulder": shoulder, "elbow": elbow, "pole": pole})


func _mat(c: Color) -> StandardMaterial3D:
	var key: String = c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	if ghost:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(c.lerp(Color(0.6, 0.8, 1.0), 0.6), 0.38)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


func _joint(parent: Node3D, offset: Vector3 = Vector3.ZERO) -> Node3D:
	var j: Node3D = Node3D.new()
	j.position = offset
	parent.add_child(j)
	return j


func _part(parent: Node3D, size: Vector3, offset: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = offset
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)


## Head position in world space (helmet camera).
func head_position() -> Vector3:
	return head.global_position + head.global_basis.y * 0.16


## Sets the global orientation and the pose from the physics state.
func apply_pose(phys: SkiPhysics, dt: float = 1.0 / 60.0) -> void:
	var fwd: Vector3 = phys.heading()
	var up: Vector3 = Vector3.UP
	if not phys.is_airborne():
		up = phys.surface_normal
	var z: Vector3 = -(fwd - up * fwd.dot(up)).normalized()
	var x: Vector3 = up.cross(z).normalized()
	var target: Basis = Basis(x, z.cross(x).normalized(), z).orthonormalized()
	var k: float = clampf(dt * 14.0, 0.0, 1.0)
	global_basis = global_basis.orthonormalized().slerp(target, k) if is_inside_tree() else target

	_tuck = phys.tuck_amount
	var lean_target: float = -deg_to_rad(phys.edge_angle) * 0.75
	if phys.braking:
		lean_target *= 0.6
	_lean = lerpf(_lean, lean_target, k)

	if phys.is_crashed():
		_crash_t += dt
		if _crash_spin == Vector3.ZERO:
			_crash_spin = Vector3(4.5, 2.0, 6.0) * (1.0 if phys.speed() > 0.0 else 0.0)
		var damp: float = clampf(phys.speed() / 20.0, 0.0, 1.0)
		body.rotation += _crash_spin * dt * damp
		body.position = Vector3(0, 0.35, 0)
		_pose_limbs(0.2, true)
		return
	_crash_t = 0.0
	_crash_spin = Vector3.ZERO
	body.rotation = Vector3(0, 0, _lean)
	body.position = Vector3.ZERO
	_pose_limbs(_tuck, false, phys.is_airborne(), phys.braking)


func _pose_limbs(tuck: float, crashed: bool, airborne: bool = false, braking: bool = false) -> void:
	# hip height above the ski: upright ~0.95 m, full tuck ~0.55 m
	var hip_h: float = lerpf(0.93, 0.56, tuck)
	if braking:
		hip_h = 0.88
	if airborne:
		hip_h -= 0.05
	if crashed:
		hip_h = 0.8
	var hip_back: float = lerpf(0.08, 0.2, tuck)
	var reach: float = Vector2(hip_h - ANKLE_H, hip_back).length()
	var cos_k: float = clampf(reach / (THIGH + SHIN), -1.0, 1.0)
	var bend: float = acos(cos_k)
	# pitch convention: rotation.x > 0 swings a hanging limb forward (towards -Z)
	var line_fwd: float = atan2(hip_back, hip_h - ANKLE_H)  # the ankle is ahead of the hip
	for leg: Dictionary in legs:
		var side: float = leg["side"]
		var spread: float = STANCE * (1.0 if not braking else 1.5)
		var hip: Node3D = leg["hip"]
		var knee: Node3D = leg["knee"]
		var foot: Node3D = leg["foot"]
		var ski: Node3D = leg["ski"]
		hip.position = Vector3(side * 0.1, hip_h, hip_back)
		# thigh swings forward (knee ahead of the hip), shin back down to the ankle
		hip.rotation = Vector3(line_fwd + bend, 0, 0)
		knee.rotation = Vector3(-2.0 * bend, 0, 0)
		foot.position = Vector3(side * spread, 0.0, 0.0)
		ski.rotation = Vector3(0, side * 0.25 if braking else 0.0, 0)  # snowplough-ish when braking
	pelvis.position = Vector3(0, hip_h, hip_back)
	torso.rotation = Vector3(-lerpf(0.25, 1.25, tuck), 0, 0)
	head.rotation = Vector3(lerpf(0.15, 1.05, tuck), 0, 0)
	for arm: Dictionary in arms:
		var side: float = arm["side"]
		var shoulder: Node3D = arm["shoulder"]
		var elbow: Node3D = arm["elbow"]
		var pole: Node3D = arm["pole"]
		# tuck: hands together in front of the face, poles under the arms pointing back
		shoulder.rotation = Vector3(lerpf(0.4, 2.0, tuck), 0, side * lerpf(0.2, -0.12, tuck))
		elbow.rotation = Vector3(lerpf(0.5, 0.8, tuck), 0, 0)
		pole.rotation = Vector3(lerpf(-1.1, 2.9, tuck), 0, 0)
		if airborne:
			shoulder.rotation.z = side * 0.6
