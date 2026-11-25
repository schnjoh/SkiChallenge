class_name Game
extends Node3D
## Playable session (race or training): world, course, rider, camera, timing, ghost, replay, HUD.
## Thin node layer over the pure classes (SkiPhysics, RaceTimer, Ghost, Leaderboard, ...).

signal run_finished(time: float, rank: int)

enum State { COUNTDOWN, RUNNING, DONE, REPLAY }

const TUNING_PATH: String = "res://resources/ski_tuning.tres"
const TRACK_ID: String = "streif"
const GHOST_PATH: String = "user://ghosts/streif.ghost"
const COUNTDOWN_S: float = 3.0
const TRAINING_START_KMH: float = 45.0
const MENU_SCENE: String = "res://scenes/main.tscn"

var world: World
var course: CourseBuilder
var gates: GateSet
var barriers: CourseBarriers
var rider: Rider
var cam: ChaseCamera
var hud: Hud
var tuning_menu: TuningMenu
var track_editor: TrackEditor
var audio: RideAudio
var pause_menu: PauseMenu
var tuning: SkiTuning
var timer: RaceTimer
var bot: BotDriver
var state: State = State.COUNTDOWN
var mode: int = 0  ## Session.Mode
var leaderboard: Leaderboard
var best_ghost: Ghost
var run_record: Ghost = Ghost.new()
var ghost_visual: RiderVisual
var trail: SkiTrail
var spectators: Spectators
var _ghost_proxy: SkiPhysics
var _countdown: float = 0.0
var _replay_t: float = 0.0
var _section_idx: int = 0
var _last_rank: int = 0


func _ready() -> void:
	mode = Session.mode
	tuning = (load(TUNING_PATH) as SkiTuning).duplicate()
	world = World.new()
	world.tree_density = float(Session.get_setting("tree_density"))
	world.shadows = int(Session.get_setting("shadows")) > 0
	world.view_distance = float(Session.get_setting("view_distance"))
	add_child(world)
	var track: TrackData = world.track
	if track == null:
		push_error("Game: track data missing")
		return
	Session.apply_viewport_settings(get_viewport())
	if int(Session.get_setting("shadows")) > 1:
		world.sun.directional_shadow_max_distance = 300.0
	gates = GateSet.for_track(track)
	barriers = CourseBarriers.build(track)
	course = CourseBuilder.new()
	course.name = "Course"
	add_child(course)
	course.build(track, gates, barriers)

	rider = Rider.new()
	rider.name = "Rider"
	add_child(rider)
	rider.barriers = barriers
	rider.setup(track.height_field, track.start_point(), SkiPhysics.dir_to_yaw(track.direction_at(0.0)), tuning)
	rider.stepped.connect(_on_rider_stepped)
	trail = SkiTrail.new()
	trail.rider = rider
	add_child(trail)
	spectators = Spectators.new()
	add_child(spectators)
	spectators.build(track, gates.finish_s)
	rider.crashed.connect(_on_crash)

	cam = ChaseCamera.new()
	cam.rider = rider
	add_child(cam)
	cam.make_current()
	world.set_camera(cam)
	if int(Session.get_setting("camera")) == 1:
		cam.toggle_mode()

	timer = RaceTimer.new(track, gates)
	timer.split.connect(_on_split)
	timer.finished.connect(_on_finish)
	timer.disqualified.connect(_on_dsq)
	leaderboard = Leaderboard.load_file()
	best_ghost = Ghost.load_file(GHOST_PATH)
	_ghost_proxy = SkiPhysics.new(tuning, track.height_field)
	if best_ghost != null and bool(Session.get_setting("ghost")):
		ghost_visual = RiderVisual.new(true)
		add_child(ghost_visual)
		ghost_visual.visible = false

	hud = Hud.new()
	add_child(hud)
	audio = RideAudio.new()
	audio.rider = rider
	audio.track = track
	add_child(audio)
	tuning_menu = TuningMenu.new(tuning)
	add_child(tuning_menu)
	track_editor = TrackEditor.new()
	track_editor.game = self
	add_child(track_editor)
	pause_menu = PauseMenu.new()
	pause_menu.game = self
	add_child(pause_menu)
	if mode == Session.Mode.TRAINING:
		_section_idx = maxi(0, _section_names().find(Session.training_section))
	restart_run()


func _section_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for s: Dictionary in world.track.sections:
		out.append(str(s["name"]))
	return out


## Restarts at the start (race) or at the selected section (training).
func restart_run() -> void:
	var track: TrackData = world.track
	timer.reset()
	run_record = Ghost.new()
	trail.clear()
	spectators.set_cheer(0.0)
	_last_rank = 0
	rider.controls_enabled = true
	if mode == Session.Mode.TRAINING and _section_idx > 0:
		var s: float = float(track.sections[_section_idx]["s"]) - 15.0
		var p: Vector3 = track.race_path().point_at(track.race_path().project(track.point_at(s)))
		rider.restart(p, SkiPhysics.dir_to_yaw(track.direction_at(s)), TRAINING_START_KMH / 3.6)
		timer.start_at(s, rider.physics.time)
	else:
		rider.restart()
	if bot:
		bot.reset()
	cam.snap()
	hud.hide_split()
	if mode == Session.Mode.TRAINING:
		state = State.RUNNING
		hud.set_mode("TRAINING · %s · Q/E Abschnitt" % track.sections[_section_idx]["name"])
		hud.show_message("", "")
	else:
		state = State.COUNTDOWN
		_countdown = COUNTDOWN_S
		hud.set_mode("RENNEN" + ("   ·   Bestzeit %s" % RaceTimer.format_time(leaderboard.best_time(TRACK_ID))
				if leaderboard.best_time(TRACK_ID) > 0.0 else ""))
	hud.show_hint("←/→ lenken · ↓/Leertaste Hocke · ↑ bremsen · Strg Vorspringen · R Neustart · C Kamera · Esc Pause")
	if ghost_visual:
		ghost_visual.visible = false
	update_frozen()


## The rider only simulates while racing/training and not in the F2 editor, countdown or replay.
func update_frozen() -> void:
	var editing: bool = track_editor != null and track_editor.active
	rider.frozen = editing or state == State.COUNTDOWN or state == State.REPLAY


## Lets the validation bot drive (demo / screenshots).
func enable_bot() -> void:
	bot = BotDriver.for_track(world.track)
	rider.autopilot = bot.drive


func _unhandled_input(event: InputEvent) -> void:
	if track_editor.active:
		return  # editor keys (Q/E fly, ...) must not restart or switch sections
	if event.is_action_pressed("restart") and state != State.REPLAY:
		restart_run()
	elif event.is_action_pressed("replay") and state == State.DONE and run_record.size() > 2:
		_start_replay()
	elif event.is_action_pressed("replay") and state == State.REPLAY:
		_stop_replay()
	elif mode == Session.Mode.TRAINING and event.is_action_pressed("section_next"):
		_section_idx = (_section_idx + 1) % world.track.sections.size()
		restart_run()
	elif mode == Session.Mode.TRAINING and event.is_action_pressed("section_prev"):
		_section_idx = (_section_idx - 1 + world.track.sections.size()) % world.track.sections.size()
		restart_run()


func _process(dt: float) -> void:
	if rider == null:
		return
	var p: SkiPhysics = rider.physics
	match state:
		State.COUNTDOWN:
			if not track_editor.active:
				_countdown -= dt
			var n: int = ceili(_countdown)
			hud.show_message(str(n) if n > 0 else "", "Bereit?" if n == 3 else "")
			if _countdown <= 0.0:
				state = State.RUNNING
				update_frozen()
				hud.show_message("LOS!", "", 0.8)
		State.REPLAY:
			_replay_t += dt
			var on: bool = run_record.apply_to(_replay_t, _ghost_proxy)
			rider.display_state(_ghost_proxy)
			if not on and _replay_t > run_record.duration():
				_replay_t = 0.0
	hud.set_speed(p.speed_kmh() if state != State.REPLAY else _ghost_proxy.speed_kmh())
	hud.set_time(timer.race_time, timer.is_running())
	hud.set_info(world.track.section_at(timer.s_now), timer.next_gate, gates.gates.size())
	_update_ghost()


func _update_ghost() -> void:
	if ghost_visual == null or best_ghost == null:
		return
	var show: bool = timer.is_running() and mode == Session.Mode.RACE and state == State.RUNNING
	if show:
		show = best_ghost.apply_to(timer.race_time, _ghost_proxy)
		ghost_visual.global_position = _ghost_proxy.pos
		ghost_visual.apply_pose(_ghost_proxy, get_process_delta_time())
	ghost_visual.visible = show


func _on_rider_stepped(_input: SkiInput, prev_pos: Vector3) -> void:
	var t1: float = rider.physics.time
	var t0: float = t1 - 1.0 / float(Engine.physics_ticks_per_second)
	timer.update(prev_pos, rider.physics.pos, t0, t1)
	if timer.is_running():
		run_record.record(timer.race_time, rider.physics)


func _on_split(index: int, t: float) -> void:
	var has_best: bool = best_ghost != null and index < best_ghost.splits.size() and best_ghost.splits[index] >= 0.0 \
			and mode == Session.Mode.RACE
	hud.show_split(index, t, t - best_ghost.splits[index] if has_best else 0.0, has_best)


func _on_finish(t: float) -> void:
	if state != State.RUNNING:
		return
	state = State.DONE
	rider.controls_enabled = false
	run_record.final_time = t
	run_record.splits = timer.split_times
	var sub: String = ""
	if mode == Session.Mode.RACE:
		var best: float = leaderboard.best_time(TRACK_ID)
		_last_rank = leaderboard.add(TRACK_ID, str(Session.get_setting("player_name")), t, timer.split_times)
		leaderboard.save()
		if best < 0.0 or t < best:
			run_record.save(GHOST_PATH)
			best_ghost = run_record  # restart_run() starts a fresh recording, the replay still works
			if ghost_visual == null and bool(Session.get_setting("ghost")):
				ghost_visual = RiderVisual.new(true)
				add_child(ghost_visual)
			sub = "Neue Bestzeit!"
		elif best > 0.0:
			sub = "Rückstand %s" % RaceTimer.format_delta(t - best)
		if _last_rank > 0:
			sub += "   ·   Platz %d" % _last_rank
	hud.show_message("ZIEL  %s" % RaceTimer.format_time(t), sub + "\nR Neustart · Enter Wiederholung · Esc Menü")
	audio.cheer()
	spectators.set_cheer(1.0)
	run_finished.emit(t, _last_rank)


func _on_dsq(reason: String) -> void:
	if state != State.RUNNING:
		return
	state = State.DONE
	hud.show_message("DISQUALIFIZIERT", reason + "\nR Neustart · Enter Wiederholung · Esc Menü")


func _on_crash(reason: String) -> void:
	if state == State.DONE:
		return
	state = State.DONE
	timer.abort()
	hud.show_message("STURZ", reason + "\nR Neustart · Enter Wiederholung · Esc Menü")


func _start_replay() -> void:
	state = State.REPLAY
	update_frozen()
	_replay_t = 0.0
	hud.show_message("", "")
	hud.set_mode("WIEDERHOLUNG · Enter beenden")


func _stop_replay() -> void:
	restart_run()


func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
