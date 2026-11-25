extends SceneTree
## Scratch probe: bot on the OSM line without crashes; logs speeds and every jump.

func _process(_d: float) -> bool:
	var track: TrackData = TrackData.load_track()
	if track.racing_line.is_empty() or OS.get_environment("REGEN") == "1":
		track.racing_line = RacingLine.build_points(track, RacingLine.optimize(track))
	var path: TrackPath = track.race_path()
	var t: SkiTuning = SkiTuning.new()
	for kv: String in OS.get_environment("TUNE").split(",", false):
		var parts: PackedStringArray = kv.split("=")
		t.set(parts[0], float(parts[1]))
	var nocrash: bool = OS.get_environment("NOCRASH") == "1"
	if nocrash:
		t.landing_crash_drop = 1000.0
		t.overload_crash_g = 100.0
		t.landing_crash_yaw = 90.0
	var phys: SkiPhysics = SkiPhysics.new(t, track.height_field)
	phys.reset(track.start_point(), SkiPhysics.dir_to_yaw(track.direction_at(0.0)), t.start_speed)
	var bot: BotDriver = BotDriver.for_track(track)
	if OS.has_environment("ALAT"):
		bot.build_speed_cap(float(OS.get_environment("ALAT")), BotDriver.BOT_DECEL)
	var next_log: float = 0.0
	var dt: float = 1.0 / 120.0
	var vmax: float = 0.0
	var gmax: float = 0.0
	var air_s0: float = -1.0
	var air_v0: float = 0.0
	var was_air: bool = false
	var cur_sec: String = ""
	var sec_t0: float = 0.0
	var sec_s0: float = 0.0
	var sec_vmin: float = INF
	var cs_last: float = 0.0
	var sec_vmax: float = 0.0
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
				print("  JUMP s=%.0f->%.0f len=%.1f v0=%.0f drop=%.2f %s" % [air_s0, bot.s, bot.s - air_s0, air_v0, phys.last_landing_drop, track.section_at(track.project(phys.pos))])
		was_air = phys.is_airborne()
		var cs_now: float = track.project(phys.pos, cs_last, 40.0)
		cs_last = cs_now
		var sec_now: String = track.section_at(cs_now)
		sec_vmin = minf(sec_vmin, phys.speed_kmh())
		sec_vmax = maxf(sec_vmax, phys.speed_kmh())
		if sec_now != cur_sec or bot.s >= path.length() - 0.5:
			if cur_sec != "":
				print("SEC %-14s t=%6.2f dt=%5.2f avg=%5.1f min=%5.1f max=%5.1f" % [cur_sec, phys.time, phys.time - sec_t0, (cs_now - sec_s0) / maxf(phys.time - sec_t0, 0.01) * 3.6, sec_vmin, sec_vmax])
			cur_sec = sec_now
			sec_t0 = phys.time
			sec_s0 = cs_now
			sec_vmin = INF
			sec_vmax = 0.0
		if OS.has_environment("TRACE") and absf(bot.s - float(OS.get_environment("TRACE"))) < 70.0 and int(phys.time * 120.0) % 6 == 0:
			var cs: float = track.project(phys.pos)
			print("   tr s=%.1f cs=%.1f y=%.2f ground=%.2f vy=%.2f v=%.1f ph=%d" % [bot.s, cs, phys.pos.y, track.height_field.height_at(phys.pos.x, phys.pos.z), phys.vel.y, phys.speed_kmh(), phys.phase])
		if bot.s >= next_log:
			print("s=%5.0f t=%6.2f v=%5.1f cap=%5.0f g=%.2f off=%5.1f %s" % [bot.s, phys.time, phys.speed_kmh(), bot.limit_at(bot.s), phys.g_load, path.lateral_offset(phys.pos, bot.s), track.section_at(track.project(phys.pos))])
			next_log += 50.0
		if phys.is_crashed():
			print("CRASH ", phys.crash_reason, " s=", bot.s, " t=", phys.time)
			break
		if bot.s >= path.length() - 0.5:
			print("FINISH t=%.2f vmax=%.1f gmax=%.2f avg=%.1f" % [phys.time, vmax, gmax, path.length() / phys.time * 3.6])
			break
	quit()
	return true
