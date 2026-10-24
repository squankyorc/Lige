export function validateRGB(rgb) {
  if (!rgb || rgb.length !== 3
    || !Array.from(rgb).every((v) => Number.isFinite(v) && v >= 0 && v <= 255)) {
    throw new RangeError('Color must contain three finite RGB values from 0 to 255.');
  }
}

/** RGB diffusion on a bounded voxel volume. Outside the volume is fixed black. */
export class VoxelWorld {
  constructor(width = 16, height = 5, depth = 16) {
    if (![width, height, depth].every((n) => Number.isSafeInteger(n) && n > 0)) {
      throw new RangeError('World dimensions must be positive integers.');
    }
    const size = width * height * depth;
    if (!Number.isSafeInteger(size) || size > 0x7fffffff) {
      throw new RangeError('World is too large.');
    }
    this.width = width;
    this.height = height;
    this.depth = depth;
    this.size = size;
    this.colors = new Float32Array(size * 3);
    this.scratch = new Float32Array(size * 3);
    this.neighbors = new Int32Array(size * 6).fill(-1);

    // Cache face adjacency once. -1 represents a black voxel outside the world.
    for (let z = 0; z < depth; z++) {
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const i = x + width * (y + height * z);
          const n = i * 6;
          if (x > 0) this.neighbors[n] = i - 1;
          if (x + 1 < width) this.neighbors[n + 1] = i + 1;
          if (y > 0) this.neighbors[n + 2] = i - width;
          if (y + 1 < height) this.neighbors[n + 3] = i + width;
          if (z > 0) this.neighbors[n + 4] = i - width * height;
          if (z + 1 < depth) this.neighbors[n + 5] = i + width * height;
        }
      }
    }
  }

  contains(x, y, z) {
    return Number.isInteger(x) && Number.isInteger(y) && Number.isInteger(z)
      && x >= 0 && x < this.width
      && y >= 0 && y < this.height
      && z >= 0 && z < this.depth;
  }

  index(x, y, z) {
    if (!this.contains(x, y, z)) throw new RangeError('Voxel is outside the world.');
    return x + this.width * (y + this.height * z);
  }

  getColor(x, y, z) {
    const offset = this.index(x, y, z) * 3;
    return [this.colors[offset], this.colors[offset + 1], this.colors[offset + 2]];
  }

  setColor(x, y, z, rgb) {
    const offset = this.index(x, y, z) * 3;
    validateRGB(rgb);
    this.colors.set(rgb, offset);
  }

  step(playerContribution = null) {
    let contributionIndex = -1;
    if (playerContribution !== null) {
      if (typeof playerContribution !== 'object') {
        throw new TypeError('Player contribution must specify a voxel and RGB color.');
      }
      contributionIndex = this.index(playerContribution.x, playerContribution.y, playerContribution.z);
      validateRGB(playerContribution.color);
    }
    const current = this.colors;
    const next = this.scratch;
    for (let i = 0; i < this.size; i++) {
      const offset = i * 3;
      let r = current[offset];
      let g = current[offset + 1];
      let b = current[offset + 2];
      for (let face = 0; face < 6; face++) {
        const neighbor = this.neighbors[i * 6 + face];
        if (neighbor < 0) continue;
        const other = neighbor * 3;
        r += current[other];
        g += current[other + 1];
        b += current[other + 2];
      }
      let divisor = 7;
      if (i === contributionIndex) {
        // The player's chosen color is an eighth sample at the standing voxel.
        // Add it only to the output so neighbors see it starting next step.
        r += playerContribution.color[0];
        g += playerContribution.color[1];
        b += playerContribution.color[2];
        divisor = 8;
      }
      // Missing neighbors count as black, including at the standing voxel.
      next[offset] = r / divisor;
      next[offset + 1] = g / divisor;
      next[offset + 2] = b / divisor;
    }
    this.colors = next;
    this.scratch = current;
  }

  reset() {
    this.colors.fill(0);
    this.scratch.fill(0);
  }
}
