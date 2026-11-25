extends SceneTree
## Validation bot (DESIGN §4.7): drives the track headless twice, checks the targets from the
## research and writes the result block into docs/validation.md. Exit code 1 on failure.
## Usage: godot --headless -s scripts/tools/validate_track.gd


func _process(_d: float) -> bool:
	var track: TrackData = TrackData.load_track()
	var tuning: SkiTuning = (load("res://resources/ski_tuning.tres") as SkiTuning).duplicate()
	var t0: int = Time.get_ticks_msec()
	var a: BotRun = BotRun.new(track, tuning).run()
	var b: BotRun = BotRun.new(track, tuning).run()
	var v: TrackValidation = TrackValidation.new(track, a, b)
	v.evaluate()
	print(v.report_text())
	print("(%d ms)" % (Time.get_ticks_msec() - t0))
	var doc: String = ProjectSettings.globalize_path("res://").path_join("../docs/validation.md")
	v.write_markdown(doc)
	quit(0 if v.passed() else 1)
	return true
