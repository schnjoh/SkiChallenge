class_name Hud
extends CanvasLayer
## In-race HUD: time, speed, gate counter, split popups with delta to the best run, messages.
## Own layout (functional reference only): time top centre, speed bottom left, info top left.

const ACCENT: Color = Color(1.0, 0.78, 0.25)
const GOOD: Color = Color(0.35, 0.95, 0.45)
const BAD: Color = Color(1.0, 0.38, 0.32)

var time_label: Label
var speed_label: Label
var speed_bar: ProgressBar
var info_label: Label
var split_panel: PanelContainer
var split_label: Label
var split_delta: Label
var message: Label
var sub_message: Label
var hint: Label
var mode_tag: Label
var _split_t: float = 0.0
var _msg_t: float = 0.0


func _init() -> void:
	layer = 10


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	time_label = _label(root, 46, Color.WHITE)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(time_label, Vector4(0.5, 0.0, 0.5, 0.0), Vector4(-200, 14, 200, 74))
	split_panel = PanelContainer.new()
	split_panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.06, 0.1, 0.75)))
	_place(split_panel, Vector4(0.5, 0.0, 0.5, 0.0), Vector4(-210, 84, 210, 130))
	root.add_child(split_panel)
	var sv: HBoxContainer = HBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	split_panel.add_child(sv)
	split_label = _label(sv, 24, Color.WHITE)
	split_delta = _label(sv, 26, GOOD)
	split_panel.visible = false

	var sp: VBoxContainer = VBoxContainer.new()
	_place(sp, Vector4(0.0, 1.0, 0.0, 1.0), Vector4(30, -120, 330, -30))
	root.add_child(sp)
	speed_label = _label(sp, 54, Color.WHITE)
	speed_bar = ProgressBar.new()
	speed_bar.max_value = 150.0
	speed_bar.show_percentage = false
	speed_bar.custom_minimum_size = Vector2(260, 8)
	var fill: StyleBoxFlat = _box(ACCENT)
	speed_bar.add_theme_stylebox_override("fill", fill)
	speed_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.15)))
	sp.add_child(speed_bar)

	info_label = _label(root, 22, Color(0.9, 0.93, 1.0))
	info_label.position = Vector2(30, 24)
	mode_tag = _label(root, 20, ACCENT)
	mode_tag.position = Vector2(30, 56)

	message = _label(root, 64, Color.WHITE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(message, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-500, -160, 500, -70))
	sub_message = _label(root, 26, Color(0.92, 0.94, 1.0))
	sub_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(sub_message, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-500, -60, 500, 60))

	hint = _label(root, 18, Color(0.85, 0.88, 0.95, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hint, Vector4(0.5, 1.0, 0.5, 1.0), Vector4(-640, -40, 640, -12))


## Anchors (left, top, right, bottom) and pixel offsets (left, top, right, bottom).
func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _box(c: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb


func _label(parent: Control, size_px: int, col: Color) -> Label:
	var l: Label = Label.new()
	var ls: LabelSettings = LabelSettings.new()
	ls.font_size = size_px
	ls.font_color = col
	ls.outline_size = maxi(4, size_px / 8)
	ls.outline_color = Color(0, 0, 0, 0.6)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func set_speed(kmh: float) -> void:
	speed_label.text = "%3.0f km/h" % kmh
	speed_bar.value = kmh


func set_time(t: float, running: bool) -> void:
	time_label.text = RaceTimer.format_time(t) if running or t > 0.0 else "0:00.00"


func set_info(section: String, gate: int, gates: int) -> void:
	info_label.text = "%s   ·   Tor %d/%d" % [section, gate, gates]


func set_mode(text: String) -> void:
	mode_tag.text = text


func show_split(index: int, t: float, delta: float, has_delta: bool) -> void:
	split_label.text = "Zwischenzeit %d   %s   " % [index + 1, RaceTimer.format_time(t)]
	split_delta.text = RaceTimer.format_delta(delta) if has_delta else ""
	split_delta.label_settings.font_color = GOOD if delta <= 0.0 else BAD
	split_panel.visible = true
	_split_t = 4.0


func hide_split() -> void:
	_split_t = 0.0
	split_panel.visible = false


func show_message(text: String, sub: String = "", seconds: float = -1.0) -> void:
	message.text = text
	sub_message.text = sub
	_msg_t = seconds


func show_hint(text: String) -> void:
	hint.text = text


func _process(dt: float) -> void:
	if _split_t > 0.0:
		_split_t -= dt
		split_panel.visible = _split_t > 0.0
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0:
			message.text = ""
			sub_message.text = ""
