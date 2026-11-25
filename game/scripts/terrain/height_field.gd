class_name HeightField
extends RefCounted
## Analytic terrain surface for physics/gameplay, independent of the renderer.
##
## Grid convention (matches Terrain3D import): sample (col, row) is a *vertex* at
## world (min_x + col * spacing, h, min_z + row * spacing). Each cell is split into two
## triangles along the diagonal (x, z) -> (x + 1, z + 1), exactly like Terrain3D's mesh,
## so the physical and the rendered surface coincide.

var width: int = 0
var depth: int = 0
var spacing: float = 1.0
var min_x: float = 0.0
var min_z: float = 0.0
var heights: PackedFloat32Array = PackedFloat32Array()


static func from_array(data: PackedFloat32Array, w: int, d: int, cell: float,
		origin_x: float, origin_z: float) -> HeightField:
	assert(data.size() == w * d, "height data size mismatch")
	var hf: HeightField = HeightField.new()
	hf.heights = data
	hf.width = w
	hf.depth = d
	hf.spacing = cell
	hf.min_x = origin_x
	hf.min_z = origin_z
	return hf


## Loads a raw little-endian float32 file (row 0 = north = smallest z).
static func load_r32(path: String, w: int, d: int, cell: float,
		origin_x: float, origin_z: float) -> HeightField:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() != w * d * 4:
		push_error("HeightField: %s has %d bytes, expected %d" % [path, bytes.size(), w * d * 4])
		return null
	return from_array(bytes.to_float32_array(), w, d, cell, origin_x, origin_z)


func max_x() -> float:
	return min_x + float(width - 1) * spacing


func max_z() -> float:
	return min_z + float(depth - 1) * spacing


func contains(x: float, z: float) -> bool:
	return x >= min_x and z >= min_z and x <= max_x() and z <= max_z()


func vertex_height(col: int, row: int) -> float:
	col = clampi(col, 0, width - 1)
	row = clampi(row, 0, depth - 1)
	return heights[row * width + col]


## Height of the triangulated surface at world (x, z). Outside the grid: clamped to the edge.
func height_at(x: float, z: float) -> float:
	var u: float = clampf((x - min_x) / spacing, 0.0, float(width - 1))
	var v: float = clampf((z - min_z) / spacing, 0.0, float(depth - 1))
	var i: int = mini(int(u), width - 2)
	var j: int = mini(int(v), depth - 2)
	var fu: float = u - float(i)
	var fv: float = v - float(j)
	var h00: float = vertex_height(i, j)
	var h11: float = vertex_height(i + 1, j + 1)
	if fu >= fv:
		var h10: float = vertex_height(i + 1, j)
		return h00 + (h10 - h00) * fu + (h11 - h10) * fv
	var h01: float = vertex_height(i, j + 1)
	return h00 + (h11 - h01) * fu + (h01 - h00) * fv


## Unit normal of the triangle containing (x, z) (pointing up).
func normal_at(x: float, z: float) -> Vector3:
	var u: float = clampf((x - min_x) / spacing, 0.0, float(width - 1))
	var v: float = clampf((z - min_z) / spacing, 0.0, float(depth - 1))
	var i: int = mini(int(u), width - 2)
	var j: int = mini(int(v), depth - 2)
	var h00: float = vertex_height(i, j)
	var h11: float = vertex_height(i + 1, j + 1)
	var dhdx: float
	var dhdz: float
	if u - float(i) >= v - float(j):
		var h10: float = vertex_height(i + 1, j)
		dhdx = (h10 - h00) / spacing
		dhdz = (h11 - h10) / spacing
	else:
		var h01: float = vertex_height(i, j + 1)
		dhdx = (h11 - h01) / spacing
		dhdz = (h01 - h00) / spacing
	return Vector3(-dhdx, 1.0, -dhdz).normalized()


## World position on the surface.
func surface_point(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)
