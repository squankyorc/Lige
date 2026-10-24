-- Portable, deterministic terrain rules mirroring Godot voxel_world.gd.
-- The API is intentionally engine-independent for testability.
local M = {}
M.MIN_Y = -256
M.MAX_Y = 256

function M.valid_y(y)
	return y >= M.MIN_Y and y <= M.MAX_Y
end

function M.height(x, z)
	local n = 12 + 8 * math.sin(x * 0.047) + 6 * math.cos(z * 0.062)
		+ 3 * math.sin((x + z) * 0.091)
	return math.max(-32, math.min(64, math.floor(n + 0.5)))
end

-- Kinds: 0 air, 1 grass, 2 dirt, 3 stone, 4 bedrock, 5 construction.
function M.kind(x, y, z, surface)
	if not M.valid_y(y) then return 0 end
	if y == M.MIN_Y then return 4 end
	surface = surface or M.height(x, z)
	if y > surface then return 0 end
	if y < surface - 5 and y > M.MIN_Y + 1 then
		local cave = math.sin(x * 0.13 + y * 0.09)
			+ math.cos(y * 0.14 + z * 0.11)
			+ math.sin(z * 0.16 + x * 0.07)
		if cave > 2.25 then return 0 end
	end
	if y == surface then return 1 end
	if y >= surface - 3 then return 2 end
	return 3
end
return M
