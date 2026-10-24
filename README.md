# Lige

[Play Lige in your browser](https://squankyorc.github.io/Lige/) · [Source repository](https://github.com/squankyorc/Lige)

A playable browser voxel game about color diffusion. Choose a player color, walk across a 16 × 5 × 16 world, and watch each step leave color that spreads through neighboring blocks. You can also paint individual voxels.

Every voxel and the player color start at **R = G = B = 0**. Selecting a player color does not immediately change any voxel: your next successful step includes that color in the block below your new position. Painting is a separate explicit action. With a black player color and no painting, a completely black world stays black through any number of steps.

Inspired by Conway's Game of Life, Lige is a synchronous cellular automaton with continuous RGB values instead of living/dead cells. A player step advances one generation; there is no timer.

## Run locally

Use Node.js 22.12 or later and the pnpm version declared in `package.json`.

```sh
corepack enable
pnpm install
pnpm dev
```

Open the local URL printed by Vite. Other commands:

```sh
pnpm test       # deterministic simulation and movement tests
pnpm build      # production bundle in dist/
pnpm preview    # serve the production bundle locally
```

The app uses Vite, vanilla JavaScript, and Three.js. It needs a modern browser with WebGL2 and hardware acceleration. No account or server is needed to play; the world is held in memory and is cleared on reload.

## Play and controls

The home screen introduces the rules and controls. Choose **Start exploring** to enter the world. During play, **Home** returns to that screen and preserves your world, player color, position, and step count. Choose **Resume world** to continue. Movement shortcuts are inactive on the home screen.

1. Choose an RGB **Player color**.
2. Take a step with **W/A/S/D**, the **arrow keys**, or the labeled movement buttons. Each successful step updates every voxel once and includes your color in the destination block below your feet.
3. To paint directly, click a voxel to select it, or use the X/Y/Z coordinate fields to select any voxel, including an interior one.
4. Choose **Paint selected** or **Paint below player** to set that voxel to the player color. Pressing **P** also paints the voxel directly below the player.

Movement is cardinal across the top surface. One physical key press produces one step; held-key repeats are ignored. Walking into the world boundary does not move the player, increment the step counter, or advance diffusion. Focus the scene to use movement shortcuts. Shortcuts are inactive while editing form fields or focusing buttons, so those controls retain their native keyboard behavior.

Drag to orbit the camera and scroll to zoom. The view buttons also orbit, zoom, and reset the camera without requiring a drag gesture. The visible-layer control cuts away upper layers so lower voxels can be inspected; it only changes the view and never changes simulation data. The coordinate/RGB inspector reports the selected voxel. **Reset** restores all voxels and the player color to black, the player to its starting position, and the step counter to zero.

The bright player marker, selection outline, and subtle voxel-edge guides are interface aids, not colored voxels. A black voxel's stored RGB channels are exactly zero even when a guide makes its edges visible.

## Diffusion rule

The base rule averages each channel independently across the voxel itself and its six face-adjacent neighbors:

```text
R_next = (R_self + R_left + R_right + R_above + R_below + R_front + R_back) / 7
G_next = (G_self + G_left + G_right + G_above + G_below + G_front + G_back) / 7
B_next = (B_self + B_left + B_right + B_above + B_below + B_front + B_back) / 7
```

On a successful move, **the block below the player's destination includes the chosen player RGB as an eighth value**:

```text
channel_next_under_player = (self + left + right + above + below + front + back + player_channel) / 8
```

All other voxels use the base divisor of seven. The destination block uses eight even when the chosen player color is black. This averages the player color into the same synchronous update; it does not overwrite the block or paint it before the update.

**Boundary behavior: outside is permanently black.** A missing neighbor contributes zero. The divisor remains seven for ordinary voxels and eight for the destination block below the player, including at faces, edges, and corners. Color can therefore drain out through the boundary. Diagonal neighbors do not contribute.

Updates are synchronous: every result reads the same old state, is written into a second buffer, and becomes visible only after the entire update completes. Each successful player step performs exactly one such update. Painting changes one voxel immediately but does not itself advance diffusion. Camera movement, selection, and layer changes also do not advance it.

RGB channels are stored in `Float32Array` buffers on a 0–255 scale. Fractional values are retained between steps; only the displayed inspector values are rounded. In a black world, the first step with player color `[240, 80, 40]` makes the destination block `[30, 10, 5]`; other voxels remain black until a later step spreads that color. Under the unforced base rule, painting an interior voxel `[210, 70, 35]` makes it and each of its six neighbors `[30, 10, 5]` after one update. Averaging only zeros gives zeros forever.

## Implementation and performance

- The world uses one Three.js `InstancedMesh` for voxel geometry, with instance colors updated when the world changes.
- Simulation uses two reusable typed-array buffers and a precomputed table of face neighbors. Each step takes work proportional to the number of voxels, with no per-voxel allocation.
- Rendering is requested when the scene or camera changes. Diffusion runs on successful discrete steps, never on animation frames or elapsed time.
- Simulation and movement are separate from the browser interface so their behavior can be tested without WebGL.

## Verification

`pnpm test` runs 21 tests covering the black invariant, independent RGB channel averaging, all six face neighbors, synchronous double-buffer behavior, color spreading, fixed-black boundary normalization, player-color injection, resetting, and the relationship between successful movement and diffusion. CI installs from the lockfile, runs the tests, builds the production bundle, and publishes main to GitHub Pages after those checks pass. Pull requests run the checks without publishing.

Browser verification on October 23, 2026 covered the home screen, black startup, exact `[240, 80, 40] / 8` injection, later neighbor spreading, direct painting without a step, home/resume state preservation, a held movement key, blocked movement, cutaway/camera controls, reset, and a 390-pixel-wide layout. This checks the tested browser; it is not a claim of compatibility with every device.

For a manual browser check:

1. Load the game and take several steps with the initial black player color and no painting; confirm selected voxel RGB values remain zero.
2. Reset, choose player color `[240, 80, 40]`, and confirm choosing alone changes no voxels. Take one step and inspect the destination block below the player; expect `[30, 10, 5]` within floating-point precision. Nearby voxels should stay black until another step.
3. Reset, choose `[210, 70, 35]`, and paint coordinate `(8, 2, 8)`. Set the player color back to black and take one step. Inspect the painted voxel and its six face neighbors; expect `[30, 10, 5]`.
4. Paint a corner away from the destination below the player, then step; verify missing outside neighbors count as black and its channel total is divided by seven. Verify the destination block still uses eight.
5. Hold a movement key; verify it takes only one step until released and pressed again. Try stepping past an edge; verify the counter and colors do not change.
6. Return **Home**, try movement keys, and choose **Resume world**; confirm the world and step count were preserved and no steps occurred on the home screen.
7. Try coordinate selection, the layer cutaway, movement/view buttons, keyboard-only painting, and reset. Confirm reset also clears the chosen player color. Check a narrow viewport and browser zoom as well.

The manual checks above are a repeatable procedure, not a claim that every browser or device has been tested.

## Accessibility and scope

Controls use labeled HTML inputs and buttons, visible keyboard focus, and a live status message for actions. Movement and painting can be performed without clicking the 3D scene, and the coordinate/RGB inspector provides a numeric view of voxel state. There is no audio.

The 3D canvas still requires vision for full spatial exploration and is not a complete screen-reader representation of the world. This first version is a fixed-size sandbox with no persistence, multiplayer, terrain editing, or continuous walking.
