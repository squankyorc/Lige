extends SceneTree
## godot --headless --path godot --script res://tests/averaging_test.gd
var fails := 0

func near(a: Vector3, b: Vector3, msg: String) -> void:
	if a.distance_to(b) > 0.001:
		fails += 1; print("FAIL ", msg, " got ", a, " want ", b)
	else:
		print("ok   ", msg)

func _init() -> void:
	var w := VoxelWorld.new(3, 3, 3)
	for i in 50: w.step()
	near(w.get_color(1, 1, 1), Vector3.ZERO, "black stays black")
	w.set_color(1, 1, 1, Vector3(140, 70, 35)); w.step()
	near(w.get_color(1, 1, 1), Vector3(20, 10, 5), "interior /7")
	near(w.get_color(2, 1, 1), Vector3(140, 70, 35) / 6.0, "face voxel /6 (5 real neighbors)")
	near(w.get_color(2, 2, 1), Vector3.ZERO, "no diagonal spread")
	var u := VoxelWorld.new(3, 3, 3)
	for z in 3: for y in 3: for x in 3: u.set_color(x, y, z, Vector3(70, 140, 210))
	for i in 20: u.step()
	near(u.get_color(0, 0, 0), Vector3(70, 140, 210), "uniform world holds at corner")
	var l := VoxelWorld.new(4, 1, 1)
	l.set_color(0, 0, 0, Vector3(245, 70, 140)); l.step()
	near(l.get_color(0, 0, 0), Vector3(122.5, 35, 70), "end /2 synchronous")
	near(l.get_color(1, 0, 0), Vector3(245, 70, 140) / 3.0, "next /3")
	near(l.get_color(2, 0, 0), Vector3.ZERO, "one face per step")
	var before := l.colors.duplicate()
	if before != l.colors: fails += 1
	var p := VoxelWorld.new(3, 3, 3)
	p.step(p.index(1, 1, 1), Vector3(80, 160, 240))
	near(p.get_color(1, 1, 1), Vector3(10, 20, 30), "player sample, interior /8")
	near(p.get_color(0, 1, 1), Vector3.ZERO, "player color reaches neighbors only next step")
	var s := VoxelWorld.new(1, 1, 1)
	s.set_color(0, 0, 0, Vector3(56, 112, 168)); s.step(0, Vector3(8, 16, 24))
	near(s.get_color(0, 0, 0), Vector3(32, 64, 96), "singleton + player /2")
	print("RESULT ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails else 0)
