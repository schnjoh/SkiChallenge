class_name TrackEditor
extends Node3D
## F2 debug view: racing line + centre line, numbered gates, free camera; drag gate poles and
## racing-line points with the mouse and save gates.json / racing_line.json.
##
## Camera: right mouse drag = look, W/A/S/D move, Q/E down/up, Shift fast, wheel = speed.
## Saving: in a development checkout into the track directory (res://data/...), in an exported
## build into user://tracks/<track>/ (loaded with priority by TrackData).

const PICK_PX: float = 22.0
const LINE_LIFT: float = 0.4
const FALLOFF_PTS: float = 6.0

var game: Game
var active: bool = false
var free_cam: Camera3D
var _lines: MeshInstance3D
var _labels: Node3D
var _panel: PanelContainer
var _status: Label
var _drag_gate: int = -1
var _drag_side: String = ""
var _drag_point: int = -1
var _drag_origin: PackedVector3Array = PackedVector3Array()
var _look: bool = false
var _speed: float = 40.0
var _yaw: float = 0.0
var _pitch: float = -0.4
var _layer: CanvasLayer


func _ready() -> void:
	free_cam = Camera3D.new()
	free_cam.far = 20000.0
	free_cam.fov = 70.0
	add_child(free_cam)
	_lines = MeshInstance3D.new()
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	_labels = Node3D.new()
	add_child(_labels)
	_layer = CanvasLayer.new()
	_layer.layer = 21
	add_child(_layer)
	_build_panel()
	_set_visible(false)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -430
	_panel.offset_right = -12
	_panel.offset_top = 12
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.88)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	_panel.add_child(v)
	var t: Label = Label.new()
	t.text = "Strecke (F2)"
	t.add_theme_font_size_override("font_size", 20)
	v.add_child(t)
	var help: Label = Label.new()
	help.text = "Linksklick + ziehen: Torstange / Rennlinienpunkt\nRechte Maus: umsehen · WASD/QE fliegen · Shift schnell"
	help.add_theme_font_size_override("font_size", 14)
	v.add_child(help)
	var row: HBoxContainer = HBoxContainer.new()
	v.add_child(row)
	for spec: Array in [["Speichern", _save], ["Tore neu", _regen_gates], ["Linie neu", _regen_line], ["Zum Fahrer", _cam_to_rider]]:
		var b: Button = Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.modulate = Color(0.7, 0.95, 0.7)
	v.add_child(_status)


func _set_visible(on: bool) -> void:
	_lines.visible = on
	_labels.visible = on
	_panel.visible = on


func toggle() -> void:
	active = not active
	_set_visible(active)
	game.update_frozen()
	if active:
		_cam_to_rider()
		free_cam.make_current()
		game.world.set_camera(free_cam)
		rebuild_overlay()
	else:
		game.cam.make_current()
		game.world.set_camera(game.cam)


func _cam_to_rider() -> void:
	var p: Vector3 = game.rider.global_position
	var d: Vector3 = game.rider.physics.heading()
	free_cam.global_position = p - d * 30.0 + Vector3.UP * 25.0
	_yaw = atan2(-d.x, -d.z)
	_pitch = -0.55
	_apply_cam_rotation()


func _apply_cam_rotation() -> void:
	free_cam.rotation = Vector3(_pitch, _yaw, 0.0)


func rebuild_overlay() -> void:
	var track: TrackData = game.world.track
	var hf: HeightField = track.height_field
	var im: ImmediateMesh = ImmediateMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for p: Vector3 in track.line_points:
		im.surface_set_color(Color(0.3, 0.9, 1.0))
		im.surface_add_vertex(Vector3(p.x, hf.height_at(p.x, p.z) + LINE_LIFT, p.z))
	im.surface_end()
	if track.racing_line.size() > 1:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
		for p: Vector3 in track.racing_line:
			im.surface_set_color(Color(1.0, 0.85, 0.1))
			im.surface_add_vertex(Vector3(p.x, hf.height_at(p.x, p.z) + LINE_LIFT, p.z))
		im.surface_end()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for g: Dictionary in game.gates.gates:
		var l: Vector2 = g["left"]
		var r: Vector2 = g["right"]
		im.surface_set_color(Color(1.0, 0.3, 0.3))
		im.surface_add_vertex(Vector3(l.x, hf.height_at(l.x, l.y) + 1.0, l.y))
		im.surface_add_vertex(Vector3(r.x, hf.height_at(r.x, r.y) + 1.0, r.y))
	im.surface_end()
	_lines.mesh = im
	for c: Node in _labels.get_children():
		c.queue_free()
	for g: Dictionary in game.gates.gates:
		var mid: Vector2 = ((g["left"] as Vector2) + (g["right"] as Vector2)) * 0.5
		var lab: Label3D = Label3D.new()
		lab.text = str(g["id"])
		lab.font_size = 96
		lab.pixel_size = 0.02
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.modulate = Color(1.0, 0.9, 0.3)
		lab.outline_size = 16
		lab.position = Vector3(mid.x, hf.height_at(mid.x, mid.y) + 4.0, mid.y)
		_labels.add_child(lab)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_track"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_look = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_speed = minf(_speed * 1.25, 600.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_speed = maxf(_speed / 1.25, 5.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pick(mb.position)
			else:
				_end_drag()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _look:
			_yaw -= mm.relative.x * 0.004
			_pitch = clampf(_pitch - mm.relative.y * 0.004, -1.5, 1.2)
			_apply_cam_rotation()
		elif _drag_gate >= 0 or _drag_point >= 0:
			_drag_to(mm.position)


func _process(dt: float) -> void:
	if not active:
		return
	var mv: Vector3 = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		mv.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		mv.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		mv.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		mv.y -= 1.0
	var fast: float = 4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	free_cam.global_position += free_cam.global_basis * mv * _speed * fast * dt


## Ground point under the mouse (ray marching on the height field).
func ground_at_screen(pos: Vector2) -> Vector3:
	var o: Vector3 = free_cam.project_ray_origin(pos)
	var d: Vector3 = free_cam.project_ray_normal(pos)
	var hf: HeightField = game.world.track.height_field
	var t: float = 0.0
	var step: float = 2.0
	while t < 6000.0:
		var p: Vector3 = o + d * t
		if p.y <= hf.height_at(p.x, p.z):
			# refine by bisection
			var a: float = maxf(0.0, t - step)
			var b: float = t
			for i in 20:
				var m: float = (a + b) * 0.5
				var q: Vector3 = o + d * m
				if q.y <= hf.height_at(q.x, q.z):
					b = m
				else:
					a = m
			return o + d * b
		t += step
		step = minf(step * 1.02, 10.0)
	return Vector3.INF


func _screen(p: Vector3) -> Vector2:
	return free_cam.unproject_position(p) if not free_cam.is_position_behind(p) else Vector2(-1e6, -1e6)


func _pick(mouse: Vector2) -> void:
	var hf: HeightField = game.world.track.height_field
	var best: float = PICK_PX
	_drag_gate = -1
	_drag_point = -1
	for i in game.gates.gates.size():
		for side: String in ["left", "right"]:
			var p: Vector2 = game.gates.gates[i][side]
			var d: float = _screen(Vector3(p.x, hf.height_at(p.x, p.y) + 1.0, p.y)).distance_to(mouse)
			if d < best:
				best = d
				_drag_gate = i
				_drag_side = side
	if _drag_gate >= 0:
		_status.text = "Tor %d (%s) ziehen" % [_drag_gate + 1, "links" if _drag_side == "left" else "rechts"]
		return
	var rl: PackedVector3Array = game.world.track.racing_line
	for i in rl.size():
		var d: float = _screen(Vector3(rl[i].x, hf.height_at(rl[i].x, rl[i].z) + LINE_LIFT, rl[i].z)).distance_to(mouse)
		if d < best:
			best = d
			_drag_point = i
	if _drag_point >= 0:
		_drag_origin = rl.duplicate()
		_status.text = "Rennlinie Punkt %d ziehen" % _drag_point


func _drag_to(mouse: Vector2) -> void:
	var g: Vector3 = ground_at_screen(mouse)
	if g == Vector3.INF:
		return
	if _drag_gate >= 0:
		game.gates.gates[_drag_gate][_drag_side] = Vector2(g.x, g.z)
		rebuild_overlay()
		return
	var track: TrackData = game.world.track
	var delta: Vector3 = Vector3(g.x, 0.0, g.z) - Vector3(_drag_origin[_drag_point].x, 0.0, _drag_origin[_drag_point].z)
	var rl: PackedVector3Array = _drag_origin.duplicate()
	var reach: int = int(FALLOFF_PTS * 3.0)
	for k in range(-reach, reach + 1):
		var i: int = _drag_point + k
		if i < 0 or i >= rl.size():
			continue
		var w: float = exp(-0.5 * pow(float(k) / FALLOFF_PTS, 2.0))
		var p: Vector3 = rl[i] + delta * w
		rl[i] = Vector3(p.x, track.height_field.height_at(p.x, p.z), p.z)
	track.racing_line = rl
	rebuild_overlay()


func _end_drag() -> void:
	if _drag_gate >= 0:
		game.gates.finalize(game.world.track)
		game.course.rebuild_gates()
		game.restart_run()  # gate indices changed: the running timer would be inconsistent
		_status.text = "Tor verschoben, Lauf neu gestartet (nicht gespeichert)"
	elif _drag_point >= 0:
		_status.text = "Rennlinie geändert (nicht gespeichert)"
		if game.bot:
			game.enable_bot()
	_drag_gate = -1
	_drag_point = -1
	rebuild_overlay()


static func save_dir(track: TrackData) -> String:
	return track.override_dir() if OS.has_feature("template") else track.dir


func _save() -> void:
	var track: TrackData = game.world.track
	var dir: String = save_dir(track)
	DirAccess.make_dir_recursive_absolute(dir)
	var e1: Error = game.gates.save(dir.path_join(GateSet.FILE))
	var e2: Error = RacingLine.save(dir.path_join(RacingLine.FILE), track.racing_line)
	_status.text = ("Gespeichert in %s" % dir) if e1 == OK and e2 == OK else ("Fehler beim Speichern (%d/%d)" % [e1, e2])


func _regen_gates() -> void:
	var track: TrackData = game.world.track
	var gs: GateSet = GateSet.generate(track)
	game.gates.gates = gs.gates
	game.gates.finalize(track)
	game.course.rebuild_gates()
	game.restart_run()
	rebuild_overlay()
	_status.text = "%d Tore neu erzeugt (nicht gespeichert)" % gs.gates.size()


func _regen_line() -> void:
	var track: TrackData = game.world.track
	track.racing_line = RacingLine.build_points(track, RacingLine.optimize(track))
	rebuild_overlay()
	_status.text = "Rennlinie neu berechnet (nicht gespeichert)"
