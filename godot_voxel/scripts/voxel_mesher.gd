class_name VoxelBaseMesher
extends RefCounted
## Faces are generated only when their neighbor is air. Mesh coordinates are chunk-local.

const SIDE = 16
const FACES = [
	{"dir": Vector3i(1, 0, 0), "corners": [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]},
	{"dir": Vector3i(-1, 0, 0), "corners": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]},
	{"dir": Vector3i(0, 1, 0), "corners": [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]},
	{"dir": Vector3i(0, -1, 0), "corners": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]},
	{"dir": Vector3i(0, 0, 1), "corners": [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]},
	{"dir": Vector3i(0, 0, -1), "corners": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]},
]
const TRIANGLES = [0, 1, 2, 0, 2, 3]

static func block_color(block: int) -> Color:
	match block:
		1: return Color("#75af51") # grass
		2: return Color("#8f6343") # dirt
		3: return Color("#82878d") # stone
		4: return Color("#252830") # unbreakable bedrock
		5: return Color("#c59453") # placed construction block
		_: return Color.WHITE

static func build(origin: Vector3i, sample: Callable) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for z in SIDE:
		for y in SIDE:
			for x in SIDE:
				var global_pos := origin + Vector3i(x, y, z)
				var block: int = sample.call(global_pos)
				if block == 0:
					continue
				var base := Vector3(x, y, z)
				for face in FACES:
					var normal: Vector3i = face["dir"]
					if sample.call(global_pos + normal) != 0:
						continue
					var corners: Array = face["corners"]
					var n := Vector3(normal.x, normal.y, normal.z)
					var color := block_color(block)
					if normal.y < 0:
						color = color.darkened(0.28)
					elif normal.y == 0:
						color = color.darkened(0.12)
					for idx in TRIANGLES:
						vertices.append(base + corners[idx])
						normals.append(n)
						colors.append(color)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	return mesh
