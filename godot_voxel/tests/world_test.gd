extends SceneTree
## Run: godot --headless --path godot_voxel --script res://tests/world_test.gd

var failures := 0

func expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", label)
	else:
		print("OK: ", label)

func _initialize() -> void:
	expect(VoxelBaseWorld.valid_y(-256), "bottom block included")
	expect(VoxelBaseWorld.valid_y(256), "top block included")
	expect(not VoxelBaseWorld.valid_y(-257), "below floor excluded")
	expect(not VoxelBaseWorld.valid_y(257), "above ceiling excluded")
	expect(VoxelBaseWorld.chunk_for(Vector3i(-1, -256, -17)) == Vector3i(-1, -16, -2), "negative chunk floor division")
	expect(VoxelBaseWorld.chunk_for(Vector3i(0, 256, 0)) == Vector3i(0, 16, 0), "upper endpoint chunk")
	expect(VoxelBaseWorld.natural_block(Vector3i(0, -256, 0)) == 4, "unbreakable base")
	expect(VoxelBaseWorld.natural_block(Vector3i(0, 257, 0)) == 0, "above world is air")
	var w := VoxelBaseWorld.new()
	var p := Vector3i(5, VoxelBaseWorld.terrain_height(5, 3) + 1, 3)
	expect(w.set_block(p, 5), "place a block")
	expect(w.get_block(p) == 5, "read placed block")
	expect(w.set_block(p, 0), "remove placed block")
	expect(w.get_block(p) == 0, "read mined block")
	expect(not w.set_block(Vector3i(5, 257, 3), 5), "cannot build above ceiling")
	expect(not w.set_block(Vector3i(5, -257, 3), 5), "cannot build below floor")
	expect(not w.set_block(Vector3i(5, -256, 3), 0), "bedrock stays")
	w.free()
	print("PASS" if failures == 0 else "FAIL: %d tests" % failures)
	quit(1 if failures else 0)
