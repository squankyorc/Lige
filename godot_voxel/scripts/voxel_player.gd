class_name VoxelBasePlayer
extends CharacterBody3D
## First-person creative mining/building with a physics raycast.

const WALK_SPEED := 7.0
const JUMP_SPEED := 7.8
const GRAVITY := 22.0
const LOOK_SENSITIVITY := 0.0025
const REACH := 7.0

var world: VoxelBaseWorld
var camera: Camera3D
var active_block := 5

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.fov = 78
	camera.current = true
	add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = movement.x * WALK_SPEED
	velocity.z = movement.z * WALK_SPEED
	move_and_slide()
	if world != null:
		world.focus(global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_viewport().set_input_as_handled()
			KEY_1: active_block = 1
			KEY_2: active_block = 2
			KEY_3: active_block = 3
			KEY_4: active_block = 5
			KEY_P:
				if world != null:
					world.save_world(global_position)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * LOOK_SENSITIVITY
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK_SENSITIVITY, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_edit(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_edit(false)

func _edit(dig: bool) -> void:
	if world == null:
		return
	var origin := camera.global_position
	var end := origin - camera.global_transform.basis.z * REACH
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var hit_point: Vector3 = hit["position"]
	var location := hit_point - normal * 0.02 if dig else hit_point + normal * 0.02
	var p := Vector3i(floori(location.x), floori(location.y), floori(location.z))
	if not dig and _would_intersect_player(p):
		return
	if world.set_block(p, 0 if dig else active_block):
		world.save_world(global_position)

func _would_intersect_player(p: Vector3i) -> bool:
	# A little extra clearance prevents trapping yourself inside a block.
	return absf(p.x + 0.5 - global_position.x) < 0.86 and absf(p.z + 0.5 - global_position.z) < 0.86 and float(p.y) < global_position.y + 1.85 and float(p.y + 1) > global_position.y
