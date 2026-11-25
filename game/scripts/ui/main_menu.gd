extends Node3D
## Main menu over the live terrain (slow camera flight along the course): race, training with
## section choice, leaderboard, settings, credits, quit.

const GAME_TITLE: String = "Schussfahrt"
const GAME_SCENE: String = "res://scenes/game.tscn"
const CREDITS_PATH: String = "res://data/credits.json"
const FLIGHT_SPEED: float = 9.0  ## m/s along the line

var world: World
var cam: Camera3D
var ui: CanvasLayer
var _pages: Dictionary = {}  ## name -> Control
var _flight_s: float = 2400.0
var _settings_widgets: Dictionary = {}


func _ready() -> void:
	DisplayServer.window_set_title(GAME_TITLE)
	world = World.new()
	world.tree_density = minf(0.5, float(Session.get_setting("tree_density")))
	world.view_distance = float(Session.get_setting("view_distance"))
	add_child(world)
	cam = Camera3D.new()
	cam.far = 20000.0
	cam.fov = 60.0
	add_child(cam)
	cam.make_current()
	world.set_camera(cam)
	Session.apply_viewport_settings(get_viewport())
	ui = CanvasLayer.new()
	add_child(ui)
	_build_ui()
	_show("main")


func _process(dt: float) -> void:
	if world.track == null:
		return
	var tr: TrackData = world.track
	_flight_s = fmod(_flight_s + dt * FLIGHT_SPEED, tr.length() - 200.0)
	var p: Vector3 = tr.point_at(_flight_s)
	var ahead: Vector3 = tr.point_at(_flight_s + 120.0)
	var side: Vector3 = tr.direction_at(_flight_s).cross(Vector3.UP)
	var pos: Vector3 = p - tr.direction_at(_flight_s) * 60.0 + side * 25.0
	pos.y = tr.height_field.height_at(pos.x, pos.z) + 35.0
	cam.global_position = cam.global_position.lerp(pos, clampf(dt * 0.8, 0.0, 1.0)) if cam.global_position != Vector3.ZERO else pos
	cam.look_at(ahead, Vector3.UP)


# --- UI construction ---------------------------------------------------------------------

func _panel(min_w: float) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.82)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.anchor_left = 0.0
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = 70
	p.offset_right = 70 + min_w
	p.offset_top = -330
	p.offset_bottom = 330
	return p


func _label(text: String, size_px: int, col: Color = Color.WHITE) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _page(n: String, min_w: float, title: String) -> VBoxContainer:
	var p: PanelContainer = _panel(min_w)
	ui.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(_label(title, 30, Color(1.0, 0.8, 0.35)))
	_pages[n] = p
	return v


func _show(n: String) -> void:
	for k: String in _pages:
		(_pages[k] as Control).visible = k == n
	if n == "leaderboard":
		_fill_leaderboard()
	var first: Button = _first_button(_pages[n])
	if first:
		first.grab_focus()


func _first_button(c: Node) -> Button:
	for ch: Node in c.get_children():
		if ch is Button:
			return ch
		var b: Button = _first_button(ch)
		if b:
			return b
	return null


func _build_ui() -> void:
	var m: VBoxContainer = _page("main", 420, "")
	m.get_child(0).queue_free()
	m.add_child(_label("SCHUSSFAHRT", 54))
	m.add_child(_label("Streif · Kitzbühel · echte Geländedaten", 18, Color(0.8, 0.86, 0.95)))
	m.add_child(HSeparator.new())
	m.add_child(_button("Rennen", func() -> void: _start(Session.Mode.RACE, "Start")))
	m.add_child(_button("Training", func() -> void: _show("training")))
	m.add_child(_button("Bestenliste", func() -> void: _show("leaderboard")))
	m.add_child(_button("Einstellungen", func() -> void: _show("settings")))
	m.add_child(_button("Credits", func() -> void: _show("credits")))
	m.add_child(_button("Beenden", func() -> void: get_tree().quit()))
	m.add_child(_label("F1 Handling-Tuning · F2 Strecken-Editor (im Spiel)", 14, Color(0.7, 0.75, 0.85)))

	var t: VBoxContainer = _page("training", 420, "Training – Abschnitt")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if world.track:
		for sec: Dictionary in world.track.sections:
			var n: String = str(sec["name"])
			list.add_child(_button("%s  (%.0f m)" % [n, float(sec["s"])], func() -> void: _start(Session.Mode.TRAINING, n)))
	t.add_child(_button("Zurück", func() -> void: _show("main")))

	var lb: VBoxContainer = _page("leaderboard", 560, "Bestenliste – Streif")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.name = "Grid"
	grid.add_theme_constant_override("h_separation", 24)
	lb.add_child(grid)
	lb.add_child(_button("Zurück", func() -> void: _show("main")))

	_build_settings()
	_build_credits()


func _fill_leaderboard() -> void:
	var grid: GridContainer = (_pages["leaderboard"] as Node).find_child("Grid", true, false)
	for c: Node in grid.get_children():
		c.queue_free()
	for h: String in ["#", "Name", "Zeit", "Datum"]:
		grid.add_child(_label(h, 18, Color(1.0, 0.8, 0.35)))
	var entries: Array = Leaderboard.load_file().entries(Game.TRACK_ID)
	if entries.is_empty():
		grid.add_child(_label("–", 18))
		grid.add_child(_label("Noch keine Zeiten", 18))
		grid.add_child(_label("", 18))
		grid.add_child(_label("", 18))
	for i in entries.size():
		var e: Dictionary = entries[i]
		grid.add_child(_label(str(i + 1), 18))
		grid.add_child(_label(str(e["name"]), 18))
		grid.add_child(_label(RaceTimer.format_time(float(e["time"])), 18))
		grid.add_child(_label(str(e.get("date", "")).left(10), 18))


func _build_settings() -> void:
	var v: VBoxContainer = _page("settings", 560, "Einstellungen")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	v.add_child(grid)
	_setting_text(grid, "player_name", "Name")
	_setting_slider(grid, "render_scale", "Auflösungsskala (3D)", 0.5, 1.0, 0.05)
	_setting_check(grid, "fsr", "FSR-Hochskalierung")
	_setting_slider(grid, "view_distance", "Sichtweite", 0.4, 1.0, 0.05)
	_setting_slider(grid, "tree_density", "Baumdichte", 0.1, 1.0, 0.05)
	_setting_option(grid, "shadows", "Schatten", ["aus", "mittel", "hoch"])
	_setting_option(grid, "msaa", "Kantenglättung (MSAA)", ["aus", "2×", "4×"])
	_setting_check(grid, "vsync", "VSync")
	_setting_check(grid, "fullscreen", "Vollbild")
	_setting_slider(grid, "master_volume", "Lautstärke", 0.0, 1.0, 0.05)
	_setting_check(grid, "ghost", "Ghost der Bestzeit")
	_setting_option(grid, "camera", "Kamera", ["Verfolger", "Helm"])
	v.add_child(_label("Mittel (Iris Xe, 60 fps): Skala 0,8 + FSR, Sichtweite 0,7, Bäume 0,5, Schatten mittel", 14,
			Color(0.7, 0.75, 0.85)))
	var row: HBoxContainer = HBoxContainer.new()
	v.add_child(row)
	row.add_child(_button("Speichern", func() -> void:
		Session.save_settings()
		Session.apply_window_settings()
		Session.apply_viewport_settings(get_viewport())
		_show("main")))
	row.add_child(_button("Standard", func() -> void:
		Session.settings = Session.DEFAULTS.duplicate()
		_refresh_settings()))
	row.add_child(_button("Zurück", func() -> void:
		Session.load_settings()
		_refresh_settings()
		_show("main")))
	_refresh_settings()


func _setting_text(grid: GridContainer, key: String, title: String) -> void:
	grid.add_child(_label(title, 18))
	var e: LineEdit = LineEdit.new()
	e.custom_minimum_size = Vector2(240, 0)
	e.max_length = 24
	e.text_changed.connect(func(t: String) -> void: Session.set_setting(key, t))
	grid.add_child(e)
	_settings_widgets[key] = e


func _setting_slider(grid: GridContainer, key: String, title: String, lo: float, hi: float, step: float) -> void:
	grid.add_child(_label(title, 18))
	var row: HBoxContainer = HBoxContainer.new()
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(200, 0)
	var val: Label = _label("", 16)
	val.custom_minimum_size = Vector2(50, 0)
	s.value_changed.connect(func(x: float) -> void:
		Session.set_setting(key, x)
		val.text = "%.2f" % x)
	row.add_child(s)
	row.add_child(val)
	grid.add_child(row)
	_settings_widgets[key] = s


func _setting_check(grid: GridContainer, key: String, title: String) -> void:
	grid.add_child(_label(title, 18))
	var c: CheckBox = CheckBox.new()
	c.toggled.connect(func(on: bool) -> void: Session.set_setting(key, on))
	grid.add_child(c)
	_settings_widgets[key] = c


func _setting_option(grid: GridContainer, key: String, title: String, items: Array[String]) -> void:
	grid.add_child(_label(title, 18))
	var o: OptionButton = OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.item_selected.connect(func(i: int) -> void: Session.set_setting(key, i))
	grid.add_child(o)
	_settings_widgets[key] = o


func _refresh_settings() -> void:
	for key: String in _settings_widgets:
		var w: Control = _settings_widgets[key]
		var v: Variant = Session.get_setting(key)
		if w is LineEdit:
			(w as LineEdit).text = str(v)
		elif w is HSlider:
			(w as HSlider).value = float(v)
			(w as HSlider).value_changed.emit(float(v))
		elif w is CheckBox:
			(w as CheckBox).button_pressed = bool(v)
		elif w is OptionButton:
			(w as OptionButton).select(int(v))


func _build_credits() -> void:
	var v: VBoxContainer = _page("credits", 640, "Credits")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	if data is Dictionary:
		for sec: Variant in (data as Dictionary).get("sections", []):
			var sd: Dictionary = sec
			list.add_child(_label(str(sd["heading"]), 20, Color(1.0, 0.8, 0.35)))
			for e: Variant in sd.get("entries", []):
				var ed: Dictionary = e
				var l: Label = _label("%s — %s\n%s" % [ed["name"], ed["license"], ed.get("url", "")], 15)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(560, 0)
				list.add_child(l)
	v.add_child(_button("Zurück", func() -> void: _show("main")))


func _start(mode: int, section: String) -> void:
	Session.mode = mode as Session.Mode
	Session.training_section = section
	get_tree().change_scene_to_file(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_show("main")
