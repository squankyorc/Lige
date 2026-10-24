import test from 'node:test';
import assert from 'node:assert/strict';
import { VoxelWorld } from '../src/simulation.js';

function closeRGB(actual, expected) {
  actual.forEach((value, channel) => {
    assert.ok(Math.abs(value - expected[channel]) < 0.00002,
      `Channel ${channel}: expected ${expected[channel]}, received ${value}`);
  });
}

test('a new world is pure black and repeated updates keep it black', () => {
  const world = new VoxelWorld();
  assert.equal(world.size, 16 * 5 * 16);
  assert.ok(world.colors.every((v) => v === 0));
  for (let i = 0; i < 100; i++) world.step();
  assert.ok(world.colors.every((v) => v === 0));
});

test('interior RGB averages include self and all six face neighbors independently', () => {
  const world = new VoxelWorld(3, 3, 3);
  const points = [[1, 1, 1], [0, 1, 1], [2, 1, 1], [1, 0, 1], [1, 2, 1], [1, 1, 0], [1, 1, 2]];
  const values = [[7, 210, 1], [14, 7, 2], [21, 14, 4], [28, 21, 8], [35, 28, 16], [42, 35, 32], [49, 42, 64]];
  points.forEach((point, i) => world.setColor(...point, values[i]));
  world.step();
  closeRGB(world.getColor(1, 1, 1), [28, 51, 127 / 7]);
});

test('updates are simultaneous and reuse exactly two buffers', () => {
  const world = new VoxelWorld(4, 1, 1);
  const first = world.colors;
  const second = world.scratch;
  world.setColor(0, 0, 0, [245, 70, 140]);
  world.step();
  assert.equal(world.colors, second);
  assert.equal(world.scratch, first);
  closeRGB(world.getColor(0, 0, 0), [35, 10, 20]);
  closeRGB(world.getColor(1, 0, 0), [35, 10, 20]);
  assert.deepEqual(world.getColor(2, 0, 0), [0, 0, 0]);
  assert.deepEqual(world.getColor(3, 0, 0), [0, 0, 0]);
  world.step();
  assert.equal(world.colors, first);
  assert.equal(world.scratch, second);
  closeRGB(world.getColor(2, 0, 0), [5, 10 / 7, 20 / 7]);
});

test('color spreads only one face per step, never diagonally or across wrapped rows', () => {
  const world = new VoxelWorld(3, 3, 3);
  world.setColor(1, 1, 1, [140, 70, 35]);
  world.step();
  assert.equal(Array.from({ length: world.size }, (_, i) => world.colors[i * 3]).filter((v) => v > 0).length, 7);
  closeRGB(world.getColor(2, 1, 1), [20, 10, 5]);
  assert.deepEqual(world.getColor(2, 2, 1), [0, 0, 0]);
  assert.deepEqual(world.getColor(2, 2, 2), [0, 0, 0]);

  const edge = new VoxelWorld(3, 3, 3);
  edge.setColor(2, 0, 0, [70, 0, 0]);
  edge.step();
  assert.deepEqual(edge.getColor(0, 1, 0), [0, 0, 0]);
  assert.deepEqual(edge.getColor(2, 2, 2), [0, 0, 0]);
});

test('faces, edges, and corners always normalize by seven with fixed-black outside', () => {
  const world = new VoxelWorld(3, 3, 3);
  for (let z = 0; z < 3; z++) {
    for (let y = 0; y < 3; y++) {
      for (let x = 0; x < 3; x++) world.setColor(x, y, z, [70, 140, 210]);
    }
  }
  world.step();
  closeRGB(world.getColor(1, 1, 1), [70, 140, 210]);
  closeRGB(world.getColor(0, 1, 1), [60, 120, 180]);
  closeRGB(world.getColor(0, 0, 1), [50, 100, 150]);
  closeRGB(world.getColor(0, 0, 0), [40, 80, 120]);
});

test('a singleton uses self plus six fixed-black outside neighbors', () => {
  const world = new VoxelWorld(1, 1, 1);
  world.setColor(0, 0, 0, [7, 14, 21]);
  world.step();
  assert.deepEqual(world.getColor(0, 0, 0), [1, 2, 3]);
});

test('fractional channel values survive diffusion without integer rounding', () => {
  const world = new VoxelWorld(1, 1, 1);
  world.setColor(0, 0, 0, [1, 0.5, 0.25]);
  world.step();
  closeRGB(world.getColor(0, 0, 0), [1 / 7, 0.5 / 7, 0.25 / 7]);
  assert.ok(world.getColor(0, 0, 0)[0] > 0);
});

test('reset clears both diffusion buffers and subsequent updates stay black', () => {
  const world = new VoxelWorld(3, 3, 3);
  world.setColor(1, 1, 1, [255, 180, 90]);
  world.step();
  world.reset();
  assert.ok(world.colors.every((v) => v === 0));
  assert.ok(world.scratch.every((v) => v === 0));
  world.step();
  assert.ok(world.colors.every((v) => v === 0));
});

test('coordinates and RGB inputs are validated before mutation', () => {
  for (const dims of [[0, 1, 1], [1, -1, 1], [1, 1.5, 1], [Infinity, 1, 1]]) {
    assert.throws(() => new VoxelWorld(...dims), RangeError);
  }
  const world = new VoxelWorld(2, 2, 2);
  assert.equal(world.contains(1, 1, 1), true);
  assert.equal(world.contains(2, 1, 1), false);
  assert.equal(world.contains(0.5, 1, 1), false);
  assert.throws(() => world.getColor(-1, 0, 0), RangeError);
  assert.throws(() => world.setColor(0, 2, 0, [1, 2, 3]), RangeError);
  for (const rgb of [null, [0, 0], [0, 0, 256], [-1, 0, 0], [NaN, 0, 0], [Infinity, 0, 0], ['1', 0, 0]]) {
    assert.throws(() => world.setColor(0, 0, 0, rgb), RangeError);
  }
  assert.deepEqual(world.getColor(0, 0, 0), [0, 0, 0]);
  world.setColor(0, 0, 0, new Float32Array([255, 0, 128]));
  assert.deepEqual(world.getColor(0, 0, 0), [255, 0, 128]);
});

test('the standing voxel averages self, six faces, and player RGB as eight independent samples', () => {
  const world = new VoxelWorld(3, 3, 3);
  const points = [[1, 1, 1], [0, 1, 1], [2, 1, 1], [1, 0, 1], [1, 2, 1], [1, 1, 0], [1, 1, 2]];
  const values = [[7, 210, 1], [14, 7, 2], [21, 14, 4], [28, 21, 8], [35, 28, 16], [42, 35, 32], [49, 42, 64]];
  points.forEach((point, i) => world.setColor(...point, values[i]));
  world.step({ x: 1, y: 1, z: 1, color: [60, 43, 129] });
  closeRGB(world.getColor(1, 1, 1), [32, 50, 32]);
});

test('the player contribution is simultaneous and reaches adjacent voxels only on a later step', () => {
  const world = new VoxelWorld(3, 3, 3);
  world.step({ x: 1, y: 1, z: 1, color: [80, 160, 240] });
  assert.deepEqual(world.getColor(1, 1, 1), [10, 20, 30]);
  assert.equal(Array.from(world.colors).filter((v) => v !== 0).length, 3);
  world.step();
  closeRGB(world.getColor(0, 1, 1), [10 / 7, 20 / 7, 30 / 7]);
  assert.deepEqual(world.getColor(0, 0, 1), [0, 0, 0]);
});

test('a boundary standing voxel still counts all six black outside samples in the divisor of eight', () => {
  const world = new VoxelWorld(1, 1, 1);
  world.setColor(0, 0, 0, [56, 112, 168]);
  world.step({ x: 0, y: 0, z: 0, color: [8, 16, 24] });
  assert.deepEqual(world.getColor(0, 0, 0), [8, 16, 24]);
});

test('invalid player contributions leave both buffers unchanged', () => {
  const world = new VoxelWorld(2, 2, 2);
  world.setColor(0, 0, 0, [70, 140, 210]);
  world.step();
  const current = world.colors;
  const scratch = world.scratch;
  const before = current.slice();
  const scratchBefore = scratch.slice();
  for (const invalid of [false, 1, {}, { x: 2, y: 0, z: 0, color: [1, 2, 3] },
    { x: 0, y: 0, z: 0, color: [0, 256, 0] }, { x: 0, y: 0, z: 0, color: [0, NaN, 0] }]) {
    assert.throws(() => world.step(invalid));
    assert.equal(world.colors, current);
    assert.equal(world.scratch, scratch);
    assert.deepEqual(world.colors, before);
    assert.deepEqual(world.scratch, scratchBefore);
  }
});
