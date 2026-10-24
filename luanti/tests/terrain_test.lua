-- Run from repository root: lua luanti/tests/terrain_test.lua
local t = dofile("luanti/games/voxel_base/mods/voxel_base/terrain.lua")
local tests = 0
local function eq(actual, expected, label)
	tests = tests + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

eq(t.valid_y(-256), true, "bottom included")
eq(t.valid_y(256), true, "top included")
eq(t.valid_y(-257), false, "below rejected")
eq(t.valid_y(257), false, "above rejected")
eq(t.kind(0, -256, 0), 4, "bedrock floor")
eq(t.kind(0, 257, 0), 0, "air above limit")
eq(t.kind(0, -257, 0), 0, "air below limit")
eq(t.height(0, 0), 18, "known deterministic height")
eq(t.kind(0, 18, 0), 1, "grass top layer")
eq(t.kind(0, 17, 0), 2, "dirt under grass")
eq(t.kind(0, 10, 0), 3, "stone beneath topsoil")
eq(t.kind(0, 19, 0), 0, "air above grass")
eq(t.kind(0, -256, 0), t.kind(0, -256, 0), "deterministic terrain")
print("PASS: " .. tests .. " terrain invariants")
