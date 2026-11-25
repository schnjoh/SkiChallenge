class_name Leaderboard
extends RefCounted
## Local leaderboard (user://leaderboard.json): best runs per track, sorted by time.

const PATH: String = "user://leaderboard.json"
const MAX_ENTRIES: int = 10

var path: String = PATH
var tracks: Dictionary = {}  ## track id -> Array of {name, time, date, splits}


static func load_file(p_path: String = PATH) -> Leaderboard:
	var lb: Leaderboard = Leaderboard.new()
	lb.path = p_path
	if FileAccess.file_exists(p_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p_path))
		if data is Dictionary and (data as Dictionary).get("tracks") is Dictionary:
			lb.tracks = (data as Dictionary)["tracks"]
	return lb


func entries(track_id: String) -> Array:
	return tracks.get(track_id, [])


func best_time(track_id: String) -> float:
	var e: Array = entries(track_id)
	return float((e[0] as Dictionary)["time"]) if e.size() > 0 else -1.0


## Inserts a finished run; returns its rank (1-based) or 0 if it did not make the list.
func add(track_id: String, player: String, time: float, splits: PackedFloat32Array) -> int:
	var e: Array = entries(track_id).duplicate()
	var entry: Dictionary = {"name": player.left(24), "time": snappedf(time, 0.001),
			"date": Time.get_datetime_string_from_system(false, true), "splits": Array(splits)}
	var rank: int = e.size()
	for i in e.size():
		if time < float((e[i] as Dictionary)["time"]):
			rank = i
			break
	if rank >= MAX_ENTRIES:
		return 0
	e.insert(rank, entry)
	if e.size() > MAX_ENTRIES:
		e.resize(MAX_ENTRIES)
	tracks[track_id] = e
	return rank + 1


func save() -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": 1, "tracks": tracks}, "\t"))
	return OK
