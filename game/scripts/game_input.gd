extends Node
## Autoload: registers all input actions (keyboard + gamepad) at startup.

const ACTIONS: Dictionary = {
	"steer_left": [KEY_LEFT, KEY_A],
	"steer_right": [KEY_RIGHT, KEY_D],
	"tuck": [KEY_DOWN, KEY_S, KEY_SPACE],
	"brake": [KEY_UP, KEY_W],
	"prejump": [KEY_CTRL, KEY_J],
	"restart": [KEY_R, KEY_BACKSPACE],
	"camera_toggle": [KEY_C],
	"debug_tuning": [KEY_F1],
	"debug_track": [KEY_F2],
	"pause": [KEY_ESCAPE],
	"section_prev": [KEY_PAGEUP, KEY_Q],
	"section_next": [KEY_PAGEDOWN, KEY_E],
	"replay": [KEY_ENTER, KEY_KP_ENTER],
}
const PAD_BUTTONS: Dictionary = {
	"tuck": [JOY_BUTTON_A],
	"brake": [JOY_BUTTON_B],
	"prejump": [JOY_BUTTON_X],
	"restart": [JOY_BUTTON_Y],
	"camera_toggle": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
	"section_prev": [JOY_BUTTON_LEFT_SHOULDER],
	"section_next": [JOY_BUTTON_RIGHT_SHOULDER],
	"replay": [JOY_BUTTON_RIGHT_STICK],
}
const PAD_AXES: Dictionary = {
	"steer_left": [JOY_AXIS_LEFT_X, -1.0],
	"steer_right": [JOY_AXIS_LEFT_X, 1.0],
	"tuck": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"brake": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


func _ready() -> void:
	register()


static func register() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: int in ACTIONS[action]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
		for btn: int in PAD_BUTTONS.get(action, []):
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.button_index = btn as JoyButton
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var ja: InputEventJoypadMotion = InputEventJoypadMotion.new()
			ja.axis = PAD_AXES[action][0] as JoyAxis
			ja.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, ja)


## Current rider input from the devices.
static func read(prejump_pressed: bool) -> SkiInput:
	var steer: float = Input.get_axis("steer_left", "steer_right")
	return SkiInput.make(steer, Input.is_action_pressed("tuck"), Input.is_action_pressed("brake"), prejump_pressed)
