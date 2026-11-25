extends Control
## Placeholder entry scene (Phase 0). Replaced by the main menu in Phase 5.

const GAME_TITLE: String = "Schussfahrt"


func _ready() -> void:
	DisplayServer.window_set_title(GAME_TITLE)
