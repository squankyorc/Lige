import { VoxelWorld, validateRGB } from './simulation.js';

/** A successful cardinal movement is exactly one diffusion tick. */
export class GameState {
  constructor(world) {
    if (!(world instanceof VoxelWorld)) throw new TypeError('GameState needs a VoxelWorld.');
    this.world = world;
    this.player = this.startPosition();
    this.playerColor = [0, 0, 0];
    this.steps = 0;
  }

  setPlayerColor(rgb) {
    validateRGB(rgb);
    this.playerColor = Array.from(rgb);
  }

  startPosition() {
    return {
      x: Math.floor(this.world.width / 2),
      y: this.world.height,
      z: Math.floor(this.world.depth / 2),
    };
  }

  move(dx, dz) {
    if (!Number.isInteger(dx) || !Number.isInteger(dz) || Math.abs(dx) + Math.abs(dz) !== 1) {
      throw new RangeError('Move must be one cardinal grid step.');
    }
    const x = this.player.x + dx;
    const z = this.player.z + dz;
    if (!this.world.contains(x, this.world.height - 1, z)) return false;
    this.world.step({ x, y: this.world.height - 1, z, color: this.playerColor });
    this.player.x = x;
    this.player.z = z;
    this.steps++;
    return true;
  }

  reset() {
    this.world.reset();
    this.player = this.startPosition();
    this.playerColor = [0, 0, 0];
    this.steps = 0;
  }
}
