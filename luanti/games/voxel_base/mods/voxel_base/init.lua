-- Luanti standalone voxel-base game. Gameplay code lives in this mod, never in engine patches.
local terrain = dofile(core.get_modpath("voxel_base") .. "/terrain.lua")
local IDS = { "air", "voxel_base:grass", "voxel_base:dirt", "voxel_base:stone",
	"voxel_base:bedrock", "voxel_base:construction" }
local tex = "voxel_white.png^[colorize:"

-- The node placement guard is applied at the item level before an item is consumed.
local function bounded_place(stack, placer, pointed)
	if pointed and pointed.type == "node" and not terrain.valid_y(pointed.above.y) then
		if placer and placer:is_player() then
			core.chat_send_player(placer:get_player_name(),
				"Build height: -256 through +256 blocks (inclusive).")
		end
		return stack
	end
	return core.item_place(stack, placer, pointed)
end

local function register_block(id, label, color, groups, extra)
	local def = {
		description = label,
		tiles = { tex .. color .. ":255" },
		groups = groups,
		on_place = bounded_place,
		is_ground_content = true,
	}
	if extra then
		for k, v in pairs(extra) do def[k] = v end
	end
	core.register_node("voxel_base:" .. id, def)
end

register_block("grass", "Grass", "#75af51", {crumbly = 3, soil = 1})
register_block("dirt", "Dirt", "#8f6343", {crumbly = 3, soil = 1})
register_block("stone", "Stone", "#82878d", {cracky = 3, stone = 1})
register_block("bedrock", "Bedrock", "#252830", {unbreakable = 1}, {diggable = false, drop = ""})
register_block("construction", "Construction", "#c59453", {cracky = 2})

-- A self-contained Game does not inherit hand-dig rules from Minetest Game.
core.override_item("", {
	tool_capabilities = {
		full_punch_interval = 0.5,
		max_drop_level = 1,
		groupcaps = {
			crumbly = {times = {[1] = 0.5, [2] = 0.3, [3] = 0.15}, uses = 0, maxlevel = 1},
			cracky = {times = {[1] = 1.8, [2] = 1.0, [3] = 0.6}, uses = 0, maxlevel = 1},
		},
		damage_groups = {fleshy = 1},
	},
})

-- Fast mapgen: edit the mapgen VoxelManip, never call set_node per block.
-- New worlds use the singlenode (all-air) mapgen selected by game.conf.
-- Reuse the data table and precompute each x/z column height.
local data = {}
core.register_on_generated(function(minp, maxp, _seed)
	local bottom = math.max(minp.y, terrain.MIN_Y)
	local top = math.min(maxp.y, terrain.MAX_Y)
	if bottom > top then return end

	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	vm:get_data(data)
	local content = {}
	for kind = 0, 5 do content[kind] = core.get_content_id(IDS[kind + 1]) end

	local width = maxp.x - minp.x + 1
	local heights = {}
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			heights[(z - minp.z) * width + (x - minp.x) + 1] = terrain.height(x, z)
		end
	end
	for z = minp.z, maxp.z do
		for y = bottom, top do
			local i = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				local surface = heights[(z - minp.z) * width + (x - minp.x) + 1]
				data[i] = content[terrain.kind(x, y, z, surface)]
				i = i + 1
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end)

core.register_on_newplayer(function(player)
	player:set_pos({x = 0, y = terrain.height(0, 0) + 5, z = 0})
end)

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	inv:set_size("main", 32)
	-- Starter creative-ish materials. Digging also drops recovered nodes.
	if inv:is_empty("main") then
		inv:set_stack("main", 1, "voxel_base:grass 99")
		inv:set_stack("main", 2, "voxel_base:dirt 99")
		inv:set_stack("main", 3, "voxel_base:stone 99")
		inv:set_stack("main", 4, "voxel_base:construction 99")
	end
	player:set_inventory_formspec(
		"formspec_version[4]size[10,7]label[0.4,0.4;Voxel Base Inventory]"
		.. "list[current_player;main;0.5,1.0;8,4;]"
		.. "listring[current_player;main]")
end)

core.register_chatcommand("height", {
	description = "Display your Y position and the valid voxel build height",
	func = function(name)
		local p = core.get_player_by_name(name)
		if not p then return false, "Player not found." end
		return true, string.format("Current Y: %.1f | block range: -256 through +256 inclusive", p:get_pos().y)
	end,
})
core.log("action", "[voxel_base] 513-level world enabled; playable block Y range = -256 to 256")
