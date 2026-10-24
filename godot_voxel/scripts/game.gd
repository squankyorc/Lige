extends Node3D
## Small playable root. Future systems should attach as sibling nodes/services.

var world: VoxelBaseWorld
var player: VoxelBasePlayer
var status: Label

func _ready() -> void:
	_setup_light()
	world = VoxelBaseWorld.new()
	world.name = "World"
	add_child(world)
	player = VoxelBasePlayer.new()
	player.name = "Player"
	player.world = world
	player.position = world.saved_position if world.has_saved_position else Vector3(0.5, VoxelBaseWorld.terrain_height(0, 0) + 4.0, 0.5)
	add_child(player)
	world.build_spawn_colliders(player.position)
	world.focus(player.position)
	_setup_ui()

func _setup_light() -> void:
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#93bedc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c5d2df")
	env.ambient_light_energy = 0.85
	sky.environment = env
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.15
	add_child(sun)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(14, 12)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(status)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(crosshair)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var p := player.global_position
	var material_name := {1: "Grass", 2: "Dirt", 3: "Stone", 5: "Construction"}[player.active_block]
	status.text = "VOXEL BASE | Y -256 to +256 inclusive\nXYZ: %d, %d, %d    Loaded chunks: %d\nWASD move  |  Mouse look  |  Space jump\nLeft click mine  |  Right click place\n1 Grass  2 Dirt  3 Stone  4 Construction (%s)\nP save  |  Esc unlock mouse" % [floori(p.x), floori(p.y), floori(p.z), world.chunks.size(), material_name]

func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(player):
		world.save_world(player.global_position)
