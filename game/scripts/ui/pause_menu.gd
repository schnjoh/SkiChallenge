class_name PauseMenu
extends CanvasLayer
## Esc: pauses the session (tree paused) with resume / restart / main menu.

var game: Game
var _panel: PanelContainer


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -180
	_panel.offset_right = 180
	_panel.offset_top = -140
	_panel.offset_bottom = 140
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var t: Label = Label.new()
	t.text = "Pause"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	v.add_child(t)
	v.add_child(_button("Weiter", func() -> void: set_open(false)))
	v.add_child(_button("Neustart", func() -> void:
		set_open(false)
		game.restart_run()))
	v.add_child(_button("Hauptmenü", func() -> void: game.go_to_menu()))
	_panel.visible = false


func _button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	return b


func set_open(open: bool) -> void:
	_panel.visible = open
	get_tree().paused = open
	if open:
		(_panel.get_child(0).get_child(1) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_open(not _panel.visible)
		get_viewport().set_input_as_handled()
