class_name TuningMenu
extends CanvasLayer
## F1 debug menu: one slider per SkiTuning value (grouped), live editing, presets as JSON.
## Built-in presets: res://resources/presets/*.json, user presets: user://presets/*.json.

signal tuning_changed

const BUILTIN_DIR: String = "res://resources/presets"
const USER_DIR: String = "user://presets"

var tuning: SkiTuning
var _panel: PanelContainer
var _rows: Dictionary = {}  ## property name -> {slider, value}
var _preset_list: OptionButton
var _name_edit: LineEdit
var _status: Label
var _updating: bool = false


func _init(p_tuning: SkiTuning = null) -> void:
	tuning = p_tuning
	layer = 20


func _ready() -> void:
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		refresh()
		_refresh_presets()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_tuning"):
		toggle()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12
	_panel.offset_top = 12
	_panel.offset_bottom = -12
	_panel.custom_minimum_size = Vector2(470, 0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.88)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var outer: VBoxContainer = VBoxContainer.new()
	_panel.add_child(outer)
	var title: Label = Label.new()
	title.text = "Handling-Tuning (F1)"
	title.add_theme_font_size_override("font_size", 20)
	outer.add_child(title)

	var presets: HBoxContainer = HBoxContainer.new()
	outer.add_child(presets)
	_preset_list = OptionButton.new()
	_preset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets.add_child(_preset_list)
	presets.add_child(_button("Laden", _on_load))
	presets.add_child(_button("Standard", _on_defaults))
	var save_row: HBoxContainer = HBoxContainer.new()
	outer.add_child(save_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Preset-Name"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_name_edit)
	save_row.add_child(_button("Speichern", _on_save))
	_status = Label.new()
	_status.modulate = Color(0.7, 0.9, 0.7)
	outer.add_child(_status)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for p: Dictionary in tuning.get_property_list():
		if p["usage"] & PROPERTY_USAGE_CATEGORY:
			continue
		if p["usage"] & PROPERTY_USAGE_GROUP:
			var g: Label = Label.new()
			g.text = str(p["name"])
			g.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
			list.add_child(g)
			continue
		if not ((p["usage"] & PROPERTY_USAGE_EDITOR) and p["hint"] == PROPERTY_HINT_RANGE):
			continue
		if p["type"] != TYPE_FLOAT and p["type"] != TYPE_INT:
			continue
		list.add_child(_slider_row(p))


func _button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _slider_row(p: Dictionary) -> Control:
	var parts: PackedStringArray = str(p["hint_string"]).split(",")
	var row: HBoxContainer = HBoxContainer.new()
	var name_l: Label = Label.new()
	name_l.text = str(p["name"])
	name_l.custom_minimum_size = Vector2(170, 0)
	name_l.clip_text = true
	row.add_child(name_l)
	var s: HSlider = HSlider.new()
	s.min_value = float(parts[0])
	s.max_value = float(parts[1])
	s.step = float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(150, 0)
	row.add_child(s)
	var val: Label = Label.new()
	val.custom_minimum_size = Vector2(95, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	var suffix: String = ""
	for part: String in parts:
		if part.begins_with("suffix:"):
			suffix = " " + part.trim_prefix("suffix:")
	var n: String = p["name"]
	var is_int: bool = p["type"] == TYPE_INT
	_rows[n] = {"slider": s, "value": val, "suffix": suffix, "int": is_int}
	s.value_changed.connect(func(v: float) -> void:
		if _updating:
			return
		tuning.set(n, int(v) if is_int else v)
		_show_value(n)
		tuning_changed.emit())
	return row


func _show_value(n: String) -> void:
	var r: Dictionary = _rows[n]
	var v: Variant = tuning.get(n)
	(r["value"] as Label).text = (str(v) if r["int"] else "%.3f" % float(v)) + str(r["suffix"])


func refresh() -> void:
	_updating = true
	for n: String in _rows:
		(_rows[n]["slider"] as HSlider).value = float(tuning.get(n))
		_show_value(n)
	_updating = false


static func list_presets() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: String in [BUILTIN_DIR, USER_DIR]:
		var da: DirAccess = DirAccess.open(d)
		if da == null:
			continue
		for f: String in da.get_files():
			if f.get_extension() == "json":
				out.append(d.path_join(f))
	return out


func _refresh_presets() -> void:
	_preset_list.clear()
	for p: String in list_presets():
		var label: String = p.get_file().get_basename() + ("" if p.begins_with("res://") else " (eigen)")
		_preset_list.add_item(label)
		_preset_list.set_item_metadata(_preset_list.item_count - 1, p)


func _on_load() -> void:
	if _preset_list.selected < 0:
		return
	var path: String = _preset_list.get_item_metadata(_preset_list.selected)
	tuning.apply_dict(SkiTuning.load_json(path).to_dict())
	refresh()
	_status.text = "Geladen: %s" % path.get_file()
	tuning_changed.emit()


func _on_defaults() -> void:
	tuning.apply_dict(SkiTuning.new().to_dict())
	refresh()
	_status.text = "Standardwerte"
	tuning_changed.emit()


func _on_save() -> void:
	var n: String = _name_edit.text.strip_edges().validate_filename()
	if n.is_empty():
		_status.text = "Bitte einen Namen eingeben"
		return
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var path: String = USER_DIR.path_join(n + ".json")
	var err: Error = tuning.save_json(path)
	_status.text = ("Gespeichert: %s" % path) if err == OK else ("Fehler %d" % err)
	_refresh_presets()
