class_name VoxelWorld
extends RefCounted
## Synchronous RGB averaging on a bounded voxel grid.
## Each block averages itself plus its EXISTING face neighbors (6-neighborhood),
## read from the pre-step buffer. The block under the player adds the player's
## color as one extra sample. Colors are static between steps.

var width: int
var height: int
var depth: int
var size: int
var colors := PackedFloat32Array()
var scratch := PackedFloat32Array()
var neighbors := PackedInt32Array()

func _init(w := 16, h := 5, d := 16) -> void:
	width = w; height = h; depth = d; size = w * h * d
	colors.resize(size * 3); colors.fill(0.0)
	scratch.resize(size * 3); scratch.fill(0.0)
	neighbors.resize(size * 6); neighbors.fill(-1)
	for z in d:
		for y in h:
			for x in w:
				var i := index(x, y, z); var n := i * 6
				if x > 0: neighbors[n] = i - 1
				if x + 1 < w: neighbors[n + 1] = i + 1
				if y > 0: neighbors[n + 2] = i - w
				if y + 1 < h: neighbors[n + 3] = i + w
				if z > 0: neighbors[n + 4] = i - w * h
				if z + 1 < d: neighbors[n + 5] = i + w * h

func contains(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height and z >= 0 and z < depth

func index(x: int, y: int, z: int) -> int:
	return x + width * (y + height * z)

func get_color(x: int, y: int, z: int) -> Vector3:
	var o := index(x, y, z) * 3
	return Vector3(colors[o], colors[o + 1], colors[o + 2])

func set_color(x: int, y: int, z: int, rgb: Vector3) -> void:
	var o := index(x, y, z) * 3
	colors[o] = clampf(rgb.x, 0, 255); colors[o + 1] = clampf(rgb.y, 0, 255); colors[o + 2] = clampf(rgb.z, 0, 255)

## contribution_index = -1 for none.
func step(contribution_index := -1, player_rgb := Vector3.ZERO) -> void:
	for i in size:
		var o := i * 3
		var r := colors[o]; var g := colors[o + 1]; var b := colors[o + 2]
		var div := 1.0
		for f in 6:
			var nb := neighbors[i * 6 + f]
			if nb < 0: continue
			var q := nb * 3
			r += colors[q]; g += colors[q + 1]; b += colors[q + 2]; div += 1.0
		if i == contribution_index:
			r += player_rgb.x; g += player_rgb.y; b += player_rgb.z; div += 1.0
		scratch[o] = r / div; scratch[o + 1] = g / div; scratch[o + 2] = b / div
	var t := colors; colors = scratch; scratch = t

func reset() -> void:
	colors.fill(0.0); scratch.fill(0.0)
