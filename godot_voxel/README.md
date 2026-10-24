# Godot voxel-base client

This is a standalone Godot 4.3+ prototype, separate from the older RGB automaton under `godot/`. Import this **folder** as a Godot project, then press F6/F5 (run scene/project).

Features: first-person walking and jumping; deterministic terrain with grass, dirt, stone, simple cave pockets, and bedrock; left-click digging; right-click placement; a 16^3 voxel chunk mesher with hidden faces culled; physics collision; 5x5 horizontal by 3 vertical chunk streaming; and persistent modified voxels in `user://voxel_world.json`. Only edited blocks are saved, not every naturally generated chunk.

**World range:** valid block Y coordinates are -256 through +256, inclusive (513 block layers). A bedrock floor exists at Y=-256, and edits outside the range are rejected. The chunk index uses floor division, so negative heights are addressed correctly. Horizontal X/Z positions are generated as explored. This is a foundation, not yet an infinite-scale optimized or networked engine.

**Controls:** WASD move; mouse look; Space jump; left mouse remove block; right mouse place block; 1=grass, 2=dirt, 3=stone, 4=construction; P saves; Esc frees mouse; click to recapture.

To test in a headless Godot install:
```
godot --headless --path godot_voxel --script res://tests/world_test.gd
```

Architecture: `voxel_world.gd` owns rules, chunk streaming, coordinate limits, edits, saves. `voxel_mesher.gd` creates only visible faces and matching static collision meshes. `voxel_player.gd` handles input and physics. `game.gd` owns presentation. Add future actors/AI/server adapters as separate systems rather than embedding them in the mesher.

Current limitations: full mesh rebuilds after edits, no greedy meshing, no asynchronous generation, no networking, no texture atlas, no multiplayer/server authority, and no compatibility guarantee between Luanti and Godot save formats. Large-scale features should first replace the mesher/streamer behind their existing interfaces.
