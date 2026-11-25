extends SceneTree
## Scratch probe: bot on the OSM line without crashes; logs speeds and every jump.

func _process(_d: float) -> bool:
	var track: TrackData = TrackData.load_track()
	var path: TrackPath = TrackPath.from_points(track.line_points)
	var t: SkiTuning = SkiTuning.new()
	var nocrash: bool = OS.get_environment("NOCRASH") == "1"
	if nocrash:
		t.landing_crash_drop = 1000.0
		t.overload_crash_g = 100.0
		t.landing_crash_yaw = 90.0
	var phys: SkiPhysics = SkiPhysics.new(t, track.height_field)
	phys.reset(track.start_point(), SkiPhysics.dir_to_yaw(track.direction_at(0.0)), t.start_speed)
	var bot: BotDriver = BotDriver.new(path)
	var next_log: float = 0.0
	var dt: float = 1.0 / 120.0
	var vmax: float = 0.0
	var gmax: float = 0.0
	var air_s0: float = -1.0
	var air_v0: float = 0.0
	var was_air: bool = false
	while phys.time < 300.0:
		var inp: SkiInput = bot.drive(phys)
		phys.step(inp, dt)
		vmax = maxf(vmax, phys.speed_kmh())
		if not phys.is_airborne():
			gmax = maxf(gmax, phys.g_load)
		if phys.is_airborne() and not was_air:
			air_s0 = bot.s
			air_v0 = phys.speed_kmh()
		if was_air and not phys.is_airborne():
			if phys.max_air_time > 0.0 and bot.s - air_s0 > 3.0:
				print("  JUMP s=%.0f->%.0f len=%.1f v0=%.0f drop=%.2f %s" % [air_s0, bot.s, bot.s - air_s0, air_v0, phys.last_landing_drop, track.section_at(air_s0)])
		was_air = phys.is_airborne()
		if bot.s >= next_log:
			print("s=%5.0f t=%6.2f v=%5.1f g=%.2f off=%5.1f %s" % [bot.s, phys.time, phys.speed_kmh(), phys.g_load, path.lateral_offset(phys.pos, bot.s), track.section_at(bot.s)])
			next_log += 50.0
		if phys.is_crashed():
			print("CRASH ", phys.crash_reason, " s=", bot.s, " t=", phys.time)
			break
		if bot.s >= path.length() - 0.5:
			print("FINISH t=%.2f vmax=%.1f gmax=%.2f avg=%.1f" % [phys.time, vmax, gmax, path.length() / phys.time * 3.6])
			break
	quit()
	return true
