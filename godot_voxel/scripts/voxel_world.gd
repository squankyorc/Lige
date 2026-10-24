class_name VoxelBaseWorld
extends Node3D
## Chunked, deterministic voxel data. Only modified blocks are persisted.
## Block coordinates (not chunk coordinates) are valid for -256 <= y <= 256, inclusive.

const MIN_Y := -256
const MAX_Y := 256
const CHUNK := 16
const HORIZONTAL_RADIUS := 2
const VERTICAL_RADIUS := 1
const SAVE_PATH := "user://voxel_world.json"
const DIRECTIONS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var edits: Dictionary = {}
var chunks: Dictionary = {}
var pending: Array[Vector3i] = []
var queued: Dictionary = {}
var desired: Dictionary = {}
var center_chunk := Vector3i(999999, 999999, 999999)
var saved_position := Vector3.ZERO
var has_saved_position := false

static func valid_y(y: int) -> bool:
	return y >= MIN_Y and y <= MAX_Y

static func chunk_for(p: Vector3i) -> Vector3i:
	# floori handles negative positions correctly (e.g. -1 maps to chunk -1).
	return Vector3i(floori(p.x / float(CHUNK)), floori(p.y / float(CHUNK)), floori(p.z / float(CHUNK)))

static func cell_key(p: Vector3i) -> String:
	return "%d,%d,%d" % [p.x, p.y, p.z]

static func terrain_height(x: int, z: int) -> int:
	return clampi(roundi(12.0 + 8.0 * sin(x * 0.047) + 6.0 * cos(z * 0.062) + 3.0 * sin((x + z) * 0.091)), -32, 64)

static func natural_block(p: Vector3i) -> int:
	if not valid_y(p.y):
		return 0
	if p.y == MIN_Y:
		return 4
	var surface := terrain_height(p.x, p.z)
	if p.y > surface:
		return 0
	# Open deterministic cave pockets below the topsoil.
	if p.y < surface - 5 and p.y > MIN_Y + 1:
		var cave := sin(p.x * 0.13 + p.y * 0.09) + cos(p.y * 0.14 + p.z * 0.11) + sin(p.z * 0.16 + p.x * 0.07)
		if cave > 2.25:
			return 0
	if p.y == surface:
		return 1
	if p.y >= surface - 3:
		return 2
	return 3

func get_block(p: Vector3i) -> int:
	if not valid_y(p.y):
		return 0
	var key := cell_key(p)
	if edits.has(key):
		return int(edits[key])
	return natural_block(p)

func set_block(p: Vector3i, kind: int) -> bool:
	if not valid_y(p.y) or p.y == MIN_Y or kind < 0 or kind > 5:
		return false
	if get_block(p) == kind:
		return false
	var key := cell_key(p)
	if kind == natural_block(p):
		edits.erase(key)
	else:
		edits[key] = kind
	var affected: Dictionary = {cell_key(chunk_for(p)): chunk_for(p)}
	for d in DIRECTIONS:
		var n := chunk_for(p + d)
		affected[cell_key(n)] = n
	for chunk in affected.values():
		var ck := cell_key(chunk)
		if chunks.has(ck):
			_build_chunk(chunk)
	return true

func _ready() -> void:
	load_world()

func focus(pos: Vector3) -> void:
	var p := Vector3i(floori(pos.x), floori(pos.y), floori(pos.z))
	var c := chunk_for(p)
	if c == center_chunk:
		return
	center_chunk = c
	# Discard requests for the old view so fast travel does not build stale chunks.
	pending.clear()
	queued.clear()
	desired.clear()
	for dz in range(-HORIZONTAL_RADIUS, HORIZONTAL_RADIUS + 1):
		for dx in range(-HORIZONTAL_RADIUS, HORIZONTAL_RADIUS + 1):
			for dy in range(-VERTICAL_RADIUS, VERTICAL_RADIUS + 1):
				var cc := c + Vector3i(dx, dy, dz)
				if cc.y * CHUNK > MAX_Y or (cc.y + 1) * CHUNK - 1 < MIN_Y:
					continue
				var ck := cell_key(cc)
				desired[ck] = true
				if not chunks.has(ck) and not queued.has(ck):
					pending.append(cc)
					queued[ck] = true
	for ck in chunks.keys():
		if not desired.has(ck):
			chunks[ck].queue_free()
			chunks.erase(ck)

func build_spawn_colliders(pos: Vector3) -> void:
	var c := chunk_for(Vector3i(floori(pos.x), floori(pos.y), floori(pos.z)))
	for dy in [-1, 0]:
		_build_chunk(c + Vector3i(0, dy, 0))

func _process(_delta: float) -> void:
	# Bounded generation budget, avoids constructing hundreds of chunks on one frame.
	var budget := 2
	while budget > 0 and not pending.is_empty():
		var cc := pending.pop_front()
		var key := cell_key(cc)
		queued.erase(key)
		if desired.has(key) and not chunks.has(key):
			_build_chunk(cc)
			budget -= 1

func _build_chunk(cc: Vector3i) -> void:
	var key := cell_key(cc)
	if chunks.has(key):
		chunks[key].free()
		chunks.erase(key)
	var origin := cc * CHUNK
	var mesh := VoxelBaseMesher.build(origin, Callable(self, "get_block"))
	var root := Node3D.new()
	root.name = "Chunk_%s" % key
	root.position = Vector3(origin)
	add_child(root)
	chunks[key] = root
	if mesh.get_surface_count() == 0:
		return
	var view := MeshInstance3D.new()
	view.mesh = mesh
	root.add_child(view)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)

func load_world() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	if parsed.has("edits") and parsed["edits"] is Dictionary:
		for key in parsed["edits"].keys():
			var p := String(key).split(",")
			if p.size() == 3 and valid_y(int(p[1])) and int(p[1]) > MIN_Y:
				edits[key] = clampi(int(parsed["edits"][key]), 0, 5)
	if parsed.has("player") and parsed["player"] is Array and parsed["player"].size() == 3:
		var a: Array = parsed["player"]
		saved_position = Vector3(float(a[0]), clampf(float(a[1]), MIN_Y + 2, MAX_Y + 4), float(a[2]))
		has_saved_position = true

func save_world(player_position: Vector3) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save world to " + SAVE_PATH)
		return
	var contents := {"version": 1, "edits": edits, "player": [player_position.x, player_position.y, player_position.z]}
	file.store_string(JSON.stringify(contents))
