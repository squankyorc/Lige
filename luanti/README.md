# Luanti voxel base

This is a standalone **Luanti Game**, not a mod for Minetest Game.

## Install
1. Install Luanti (formerly Minetest).
2. Copy `luanti/games/voxel_base` into Luanti's `games/` folder.
3. Launch Luanti, choose the **Voxel Base** game, create a **new world**, and use the **singlenode** mapgen (the only mapgen allowed by `game.conf`).
4. Start the world. Luanti's native mapblock streaming, collisions, multiplayer protocol, and world database handle the simulation base.

Controls are Luanti defaults: WASD movement, Space jump, mouse look, left click dig, right click place, number keys select hotbar stacks, I inventory. Starter stacks give grass, dirt, stone, and construction blocks. The `/height` chat command shows altitude.

**Valid block Y is -256 through +256 inclusive** (513 levels). Y=-256 is unbreakable bedrock, Y=256 can contain player-placed blocks, and item placement outside the bounds is rejected. Generated land has shallow hills and underground caves. All other altitudes outside the bounds are air; the limit is on blocks, not the camera/player position.

Generated terrain is deterministic and uses the same equation as Godot's `godot_voxel` starter project, though engines have different rendering, physics, and map storage and are not network-compatible.

## Tests
From the repository root with Lua installed:
```
lua luanti/tests/terrain_test.lua
```

Luanti automatically persists generated and player-edited voxels to the world database. Never run this against an old world with another mapgen; use a new world so previously generated data does not violate height rules.

## Technical scope
The engine generates only mapblocks that players visit. The game mod registers five basic block types, a starter inventory, and one VoxelManip mapgen callback. No crafting, entities, networking bridge to Godot, or external content packs are included yet. This minimal surface is intentionally suitable for adding land claims, AI simulation, factions, storage, and server logic in later versions.
