extends SceneTree
## Generates racing_line.json and gates.json for a track from the pipeline output.
## Usage: godot --headless -s scripts/tools/generate_track.gd [-- --force]
## Existing (hand-edited) files are kept unless --force is given.


func _process(_d: float) -> bool:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	var track: TrackData = TrackData.load_track()
	var rl_path: String = track.dir.path_join(RacingLine.FILE)
	if force or not FileAccess.file_exists(rl_path):
		track.racing_line = RacingLine.build_points(track, RacingLine.optimize(track))
		RacingLine.save(rl_path, track.racing_line)
		print("racing line: %d points, %.0f m" % [track.racing_line.size(), track.race_path().length()])
	var g_path: String = track.dir.path_join(GateSet.FILE)
	if force or not FileAccess.file_exists(g_path):
		var gs: GateSet = GateSet.generate(track)
		gs.save(g_path)
		print("gates: %d" % gs.gates.size())
	quit()
	return true
