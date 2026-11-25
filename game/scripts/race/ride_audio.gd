class_name RideAudio
extends Node
## Procedural sounds (own synthesis, no external assets): wind by speed, edge scraping by
## skid/edge load, crowd murmur near the finish and a cheer on finishing. Loops are synthesised
## once at start-up as AudioStreamWAV and only modulated (volume/pitch) at runtime.

const RATE: int = 22050
const LOOP_S: float = 2.0
const CROWD_RANGE_M: float = 350.0

var rider: Rider
var track: TrackData
var wind: AudioStreamPlayer
var edge: AudioStreamPlayer
var crowd: AudioStreamPlayer
var cheer_player: AudioStreamPlayer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cheer_t: float = 0.0


func _ready() -> void:
	# the dummy driver (headless tests/tools) never mixes, so stopped playbacks would leak at exit
	if AudioServer.get_driver_name() == "Dummy" or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = 1234
	wind = _player(_loop(_wind_sample), "Wind")
	edge = _player(_loop(_edge_sample), "Edge")
	crowd = _player(_loop(_crowd_sample), "Crowd")
	cheer_player = _player(_loop(_cheer_sample), "Cheer")
	for p: AudioStreamPlayer in [wind, edge, crowd]:
		p.volume_db = -80.0
		p.play()
	cheer_player.volume_db = -80.0


func _player(stream: AudioStream, n: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	p.name = n
	add_child(p)
	return p


## Synthesises a seamless loop from a per-sample generator func(i, state) -> float.
func _loop(gen: Callable) -> AudioStreamWAV:
	var n: int = int(RATE * LOOP_S)
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(n)
	var st: Dictionary = {"a": 0.0, "b": 0.0, "c": 0.0, "d": 0.0}
	for i in n:
		raw[i] = gen.call(i, st)
	# crossfade the end into the start for a click-free loop
	var fade: int = RATE / 10
	for i in fade:
		var w: float = float(i) / float(fade)
		raw[i] = raw[i] * w + raw[n - fade + i] * (1.0 - w)
	var peak: float = 0.0001
	for v: float in raw:
		peak = maxf(peak, absf(v))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize((n - fade) * 2)
	for i in n - fade:
		bytes.encode_s16(i * 2, int(clampf(raw[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n - fade
	return wav


func _wind_sample(i: int, st: Dictionary) -> float:
	# brown-ish noise with a slow gust modulation
	st["a"] = clampf(float(st["a"]) * 0.995 + _rng.randf_range(-1.0, 1.0) * 0.06, -1.0, 1.0)
	st["b"] = lerpf(float(st["b"]), float(st["a"]), 0.08)
	var gust: float = 0.75 + 0.25 * sin(TAU * float(i) / float(RATE) * 0.5)
	return float(st["b"]) * gust


func _edge_sample(i: int, st: Dictionary) -> float:
	# high-passed noise with grainy amplitude (snow crystals under the edge)
	var w: float = _rng.randf_range(-1.0, 1.0)
	var hp: float = w - float(st["a"])
	st["a"] = lerpf(float(st["a"]), w, 0.3)
	if i % 220 == 0:
		st["c"] = _rng.randf_range(0.4, 1.0)
	return hp * float(st["c"])


func _crowd_sample(i: int, st: Dictionary) -> float:
	# murmur: band-limited noise with several slow, independent "voices" (amplitude modulation)
	var w: float = _rng.randf_range(-1.0, 1.0)
	st["a"] = lerpf(float(st["a"]), w, 0.12)
	st["b"] = lerpf(float(st["b"]), float(st["a"]), 0.25)
	var t: float = float(i) / float(RATE)
	var am: float = 0.6 + 0.2 * sin(TAU * t * 2.1) + 0.15 * sin(TAU * t * 3.7 + 1.0) + 0.1 * sin(TAU * t * 5.3 + 2.0)
	return (float(st["a"]) - float(st["b"])) * am


func _cheer_sample(i: int, st: Dictionary) -> float:
	var w: float = _rng.randf_range(-1.0, 1.0)
	st["a"] = lerpf(float(st["a"]), w, 0.35)
	var t: float = float(i) / float(RATE)
	var am: float = 0.7 + 0.3 * sin(TAU * t * 7.0) * sin(TAU * t * 1.3)
	return float(st["a"]) * am


func cheer() -> void:
	if cheer_player == null:
		return
	_cheer_t = 4.0
	cheer_player.volume_db = -6.0
	if not cheer_player.playing:
		cheer_player.play()


func _process(dt: float) -> void:
	if rider == null or rider.physics == null:
		return
	var p: SkiPhysics = rider.physics
	var kmh: float = p.speed_kmh()
	var paused: bool = rider.frozen
	var wv: float = clampf(kmh / 140.0, 0.0, 1.2)
	wind.volume_db = -80.0 if paused else linear_to_db(maxf(0.0001, wv * wv * 0.9 + (0.15 if p.is_airborne() else 0.0)))
	wind.pitch_scale = 0.6 + wv * 0.8
	var on_snow: bool = not p.is_airborne() and not paused and kmh > 3.0
	var e: float = clampf(p.skid * 1.2 + absf(p.edge_angle) / 90.0 * 0.4, 0.0, 1.0) if on_snow else 0.0
	edge.volume_db = linear_to_db(maxf(0.0001, e * 0.8))
	edge.pitch_scale = 0.8 + clampf(kmh / 120.0, 0.0, 1.0) * 0.6
	var d: float = p.pos.distance_to(track.finish_point())
	var c: float = clampf(1.0 - d / CROWD_RANGE_M, 0.0, 1.0)
	crowd.volume_db = linear_to_db(maxf(0.0001, c * c * 0.7))
	if _cheer_t > 0.0:
		_cheer_t -= dt
		cheer_player.volume_db = linear_to_db(maxf(0.0001, clampf(_cheer_t / 4.0, 0.0, 1.0) * 0.9))
		if _cheer_t <= 0.0:
			cheer_player.stop()


func _exit_tree() -> void:
	# stop playback explicitly, otherwise the playback objects outlive the audio server at quit
	for p: AudioStreamPlayer in [wind, edge, crowd, cheer_player]:
		if p:
			p.stop()
			p.stream = null
