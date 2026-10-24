# 513-layer voxel game foundation

The goal is a scalable building block for a much larger game, **not** to add complex gameplay before the base is reliable.

The older RGB-diffusion Lige projects under `src/` and `godot/` are left untouched. This branch adds two **separately playable** reference implementations:

* `godot_voxel/`: native Godot 4 client/prototype with customizable renderer, movement, mining, build blocks, chunk streaming and modified-voxel saves.
* `luanti/games/voxel_base/`: standalone Luanti game using the Luanti native voxel database, mapblock networking, physics, inventory, and generation.

**World contract:** block Y coordinates include every integer from -256 through +256 (513 levels). Reject placements outside that range. Bottom layer is indestructible bedrock at -256; air outside. X and Z use signed coordinates and grow as chunks are visited. Match the terrain formula in the two independent prototypes, but do **not** imply that they are one shared runtime or share save files.

### Future growth plan

1. Prove stable chunk rendering, editing, persistence, loading and negative coordinate handling.
2. Define an engine-neutral world/chunk data protocol and versioned edit messages before joining clients and servers.
3. Pick one authoritative multiplayer server (Luanti *or* custom Godot headless); do not run competing authoritative worlds or pretend Luanti and Godot clients can connect without a translation/protocol layer.
4. Add land ownership, inventory, crafting and permission-controlled block changes server-side.
5. Add chunk-local animal/villager simulations and bounded NPC memory/decision scheduling.
6. Add towns, dungeons, AI factions, social tools and magic as independent modules after performance profiling.

Critical scaling rules: stream chunks around players, store natural terrain as deterministic functions + sparse changes, only mesh visible faces, and never allocate 513 high layers for every horizontal chunk. Future work: greedy meshing, mesh generation off main thread, chunk-level save format, LOD, and authoritative server with anti-cheat.

### Local validation
Godot: `godot --headless --path godot_voxel --script res://tests/world_test.gd`
Luanti: `lua luanti/tests/terrain_test.lua`

Live runtime QA was not available during code authoring; review and test on installed engine builds before release.
