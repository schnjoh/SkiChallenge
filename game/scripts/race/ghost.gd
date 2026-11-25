class_name Ghost
extends RefCounted
## Recorded run: rider states at 60 Hz (race time based). Used for the ghost of the best run
## and for the replay. Saved as a small binary file (user://ghosts/<track>.ghost).

const RATE_HZ: float = 60.0
const STRIDE: int = 12  ## t, x, y, z, yaw, tuck, edge, phase, nx, ny, nz, speed
const MAGIC: int = 0x47485354  # "GHST"
const VERSION: int = 1

var data: PackedFloat32Array = PackedFloat32Array()
var final_time: float = -1.0
var splits: PackedFloat32Array = PackedFloat32Array()
var _next_t: float = 0.0


func clear() -> void:
	data = PackedFloat32Array()
	final_time = -1.0
	splits = PackedFloat32Array()
	_next_t = 0.0


func size() -> int:
	return data.size() / STRIDE


func duration() -> float:
	return data[(size() - 1) * STRIDE] if size() > 0 else 0.0


## Adds a sample if 1/60 s passed since the last one (call every physics step).
func record(t: float, phys: SkiPhysics) -> void:
	if t + 1e-6 < _next_t:
		return
	_next_t = t + 1.0 / RATE_HZ
	var n: Vector3 = phys.surface_normal
	data.append_array(PackedFloat32Array([t, phys.pos.x, phys.pos.y, phys.pos.z, phys.yaw, phys.tuck_amount,
			phys.edge_angle, float(phys.phase), n.x, n.y, n.z, phys.speed()]))


## Writes the interpolated state at time t into a proxy SkiPhysics (for RiderVisual.apply_pose).
## Returns false before the first / after the last sample.
func apply_to(t: float, proxy: SkiPhysics) -> bool:
	var n: int = size()
	if n == 0:
		return false
	var lo: int = 0
	var hi: int = n - 1
	if t <= data[0]:
		hi = 0
	elif t >= data[hi * STRIDE]:
		lo = hi
	else:
		while hi - lo > 1:
			var mid: int = (lo + hi) >> 1
			if data[mid * STRIDE] <= t:
				lo = mid
			else:
				hi = mid
	var a: int = lo * STRIDE
	var b: int = hi * STRIDE
	var span: float = data[b] - data[a]
	var f: float = clampf((t - data[a]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	proxy.pos = Vector3(lerpf(data[a + 1], data[b + 1], f), lerpf(data[a + 2], data[b + 2], f), lerpf(data[a + 3], data[b + 3], f))
	proxy.yaw = lerp_angle(data[a + 4], data[b + 4], f)
	proxy.tuck_amount = lerpf(data[a + 5], data[b + 5], f)
	proxy.edge_angle = lerpf(data[a + 6], data[b + 6], f)
	proxy.phase = int(data[a + 7]) as SkiPhysics.Phase
	proxy.surface_normal = Vector3(data[a + 8], data[a + 9], data[a + 10]).normalized()
	var spd: float = lerpf(data[a + 11], data[b + 11], f)
	proxy.vel = SkiPhysics.yaw_to_dir(proxy.yaw) * spd
	return t >= data[0] and t <= data[(n - 1) * STRIDE]


func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_32(MAGIC)
	f.store_32(VERSION)
	f.store_float(final_time)
	f.store_32(splits.size())
	for s: float in splits:
		f.store_float(s)
	f.store_32(data.size())
	f.store_buffer(data.to_byte_array())
	return OK


static func load_file(path: String) -> Ghost:
	if not FileAccess.file_exists(path):
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 16 or f.get_32() != MAGIC or f.get_32() != VERSION:
		return null
	var g: Ghost = Ghost.new()
	g.final_time = f.get_float()
	var ns: int = f.get_32()
	if ns > 64:
		return null
	for i in ns:
		g.splits.append(f.get_float())
	var nd: int = f.get_32()
	if nd % STRIDE != 0 or nd * 4 > f.get_length() - f.get_position():
		return null
	g.data = f.get_buffer(nd * 4).to_float32_array()
	return g
