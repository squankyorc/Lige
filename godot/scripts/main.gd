extends Node3D
## Lige: third-person voxel color automaton. Each successful step = one synchronous averaging tick.

const W := 16
const H := 5
const D := 16
const PRESETS := [Color8(240, 80, 40), Color8(40, 200, 90), Color8(50, 110, 240), Color8(250, 220, 40),
	Color8(200, 60, 220), Color8(40, 220, 230), Color8(255, 255, 255), Color8(0, 0, 0)]

var world := VoxelWorld.new(W, H, D)
var player := Vector2i(W / 2, D / 2)
var player_color := Color(0, 0, 0)
var steps := 0
var reveal := true
var cut_layers := 0
var mm := MultiMesh.new()
var player_node: MeshInstance3D
var cam: Camera3D
var yaw := 0.6
var pitch := -0.6
var dist := 14.0
var orbiting := false
var hud: Label
var swatch: ColorRect
var picker: ColorPickerButton

func _ready() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.53, 0.7, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.6, 0.65); e.ambient_light_energy = 0.7
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 35, 0); sun.shadow_enabled = true; add_child(sun)
	# Grass ground under the grid
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.55, 0.25); ground.material_override = gm
	ground.position = Vector3(W / 2.0, -0.01, D / 2.0); add_child(ground)
	# Voxels via MultiMesh with per-instance color
	var box := BoxMesh.new(); box.size = Vector3(0.96, 0.96, 0.96)
	var vm := StandardMaterial3D.new(); vm.vertex_color_use_as_albedo = true; vm.roughness = 0.9; box.material = vm
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = box; mm.instance_count = world.size
	for z in D: for y in H: for x in W:
		mm.set_instance_transform(world.index(x, y, z), Transform3D(Basis(), Vector3(x + 0.5, y + 0.5, z + 0.5)))
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; add_child(mmi)
	# Player: blocky character
	player_node = MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.3; cm.height = 1.6; player_node.mesh = cm
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.95, 0.85, 0.7); pmat.emission_enabled = true; pmat.emission = Color(0.2, 0.2, 0.2)
	player_node.material_override = pmat; add_child(player_node)
	cam = Camera3D.new(); add_child(cam)
	_build_ui(); _refresh()

func _build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var panel := PanelContainer.new(); panel.position = Vector2(12, 12); layer.add_child(panel)
	var v := VBoxContainer.new(); panel.add_child(v)
	var t := Label.new(); t.text = "LIGE"; t.add_theme_font_size_override("font_size", 28); v.add_child(t)
	var row := HBoxContainer.new(); v.add_child(row)
	swatch = ColorRect.new(); swatch.custom_minimum_size = Vector2(28, 28); row.add_child(swatch)
	picker = ColorPickerButton.new(); picker.text = "Pick color"; picker.edit_alpha = false; picker.custom_minimum_size = Vector2(110, 28)
	picker.color_changed.connect(func(c): _set_color(c)); row.add_child(picker)
	hud = Label.new(); v.add_child(hud)
	var help := Label.new(); help.text = "WASD/Arrows: step (one tick)   1-8: preset colors   Space: paint block below\nRight-drag / Q E: orbit   Wheel: zoom   F: reveal faint   [ ]: cut layers   R: reset   Esc: quit"
	help.add_theme_font_size_override("font_size", 13); v.add_child(help)

func _set_color(c: Color) -> void:
	player_color = Color(c.r, c.g, c.b); picker.color = player_color; _refresh()

func _rgb(c: Color) -> Vector3: return Vector3(c.r8, c.g8, c.b8)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT: orbiting = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed: dist = maxf(4, dist - 1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed: dist = minf(40, dist + 1)
	elif ev is InputEventMouseMotion and orbiting:
		yaw -= ev.relative.x * 0.006; pitch = clampf(pitch - ev.relative.y * 0.006, -1.45, -0.1)
	elif ev is InputEventKey and ev.pressed:
		var k: int = ev.keycode
		if k >= KEY_1 and k <= KEY_8: _set_color(PRESETS[k - KEY_1]); return
		match k:
			KEY_W, KEY_UP: _move(Vector2(0, -1))
			KEY_S, KEY_DOWN: _move(Vector2(0, 1))
			KEY_A, KEY_LEFT: _move(Vector2(-1, 0))
			KEY_D, KEY_RIGHT: _move(Vector2(1, 0))
			KEY_SPACE:
				world.set_color(player.x, H - 1, player.y, _rgb(player_color)); _refresh()
			KEY_F: reveal = not reveal; _refresh()
			KEY_BRACKETLEFT: cut_layers = mini(H - 1, cut_layers + 1); _refresh()
			KEY_BRACKETRIGHT: cut_layers = maxi(0, cut_layers - 1); _refresh()
			KEY_R: world.reset(); player = Vector2i(W / 2, D / 2); player_color = Color(0, 0, 0); steps = 0; picker.color = player_color; _refresh()
			KEY_ESCAPE: get_tree().quit()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q): yaw += delta * 1.5
	if Input.is_key_pressed(KEY_E): yaw -= delta * 1.5
	var target := player_node.position + Vector3(0, 0.5, 0)
	var off := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off; cam.look_at(target)

func _move(input: Vector2) -> void:
	# Camera-relative, snapped to a cardinal grid step.
	var fwd := Vector2(-sin(yaw), -cos(yaw)); var right := Vector2(cos(yaw), -sin(yaw))
	var dir := fwd * -input.y + right * input.x
	var d := Vector2i(int(signf(dir.x)), 0) if absf(dir.x) > absf(dir.y) else Vector2i(0, int(signf(dir.y)))
	var n := player + d
	if not world.contains(n.x, H - 1, n.y): hud_flash("World edge: no step taken."); return
	world.step(world.index(n.x, H - 1, n.y), _rgb(player_color))
	player = n; steps += 1; _refresh()

var _flash := ""
func hud_flash(s: String) -> void: _flash = s; _refresh(); _flash = ""

func _refresh() -> void:
	for z in D: for y in H: for x in W:
		var i := world.index(x, y, z); var o := i * 3
		var r := world.colors[o]; var g := world.colors[o + 1]; var b := world.colors[o + 2]
		var s := 1.0; var peak := maxf(r, maxf(g, b))
		if reveal and peak > 0: s = pow(255.0 / peak, 0.75)
		var c := Color(r * s / 255.0, g * s / 255.0, b * s / 255.0)
		if y >= H - cut_layers: c.a = 0.0
		mm.set_instance_color(i, c)
		if y >= H - cut_layers: mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		else: mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x + 0.5, y + 0.5, z + 0.5)))
	player_node.position = Vector3(player.x + 0.5, H + 0.8, player.y + 0.5)
	swatch.color = player_color
	var below := world.get_color(player.x, H - 1, player.y)
	hud.text = "Step %03d   Pos %d,%d   Color RGB %d,%d,%d\nBlock below RGB %.1f, %.1f, %.1f   Reveal faint: %s%s" % [steps, player.x, player.y,
		player_color.r8, player_color.g8, player_color.b8, below.x, below.y, below.z, "on" if reveal else "off",
		("\n" + _flash) if _flash != "" else ""]
