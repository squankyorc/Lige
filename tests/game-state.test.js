import test from 'node:test';
import assert from 'node:assert/strict';
import { VoxelWorld } from '../src/simulation.js';
import { GameState } from '../src/game-state.js';

test('player starts at the center above the voxel volume', () => {
  const game = new GameState(new VoxelWorld(5, 3, 7));
  assert.deepEqual(game.player, { x: 2, y: 3, z: 3 });
  assert.deepEqual(game.playerColor, [0, 0, 0]);
  assert.equal(game.steps, 0);
});

test('each successful cardinal move triggers exactly one update and one counted step', () => {
  const world = new VoxelWorld(5, 2, 5);
  const game = new GameState(world);
  let updates = 0;
  const step = world.step.bind(world);
  world.step = (contribution) => { updates++; step(contribution); };
  world.setColor(2, 1, 2, [70, 140, 210]);
  for (const direction of [[1, 0], [0, 1], [-1, 0], [0, -1]]) {
    assert.equal(game.move(...direction), true);
  }
  assert.equal(updates, 4);
  assert.equal(game.steps, 4);
  assert.deepEqual(game.player, { x: 2, y: 2, z: 2 });
  assert.ok(world.getColor(2, 1, 2)[0] < 70);
});

test('blocked moves preserve the player, color buffers, and step count', () => {
  const world = new VoxelWorld(1, 1, 1);
  const game = new GameState(world);
  game.setPlayerColor([255, 128, 64]);
  world.setColor(0, 0, 0, [1, 2, 3]);
  const buffer = world.colors;
  for (const direction of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    assert.equal(game.move(...direction), false);
  }
  assert.equal(game.steps, 0);
  assert.equal(world.colors, buffer);
  assert.deepEqual(world.getColor(0, 0, 0), [1, 2, 3]);
  assert.deepEqual(game.player, { x: 0, y: 1, z: 0 });
});

test('invalid diagonal, zero, fractional, and multi-cell moves are rejected', () => {
  const game = new GameState(new VoxelWorld(5, 2, 5));
  for (const direction of [[0, 0], [1, 1], [2, 0], [0.5, 0.5], [NaN, 1], [Infinity, 0], ['1', 0]]) {
    assert.throws(() => game.move(...direction), RangeError);
  }
  assert.equal(game.steps, 0);
  assert.deepEqual(game.player, { x: 2, y: 2, z: 2 });
});

test('painting does not advance time and reset restores player, steps, and black', () => {
  const world = new VoxelWorld(3, 2, 3);
  const game = new GameState(world);
  game.setPlayerColor([255, 180, 90]);
  world.setColor(1, 1, 1, [255, 100, 50]);
  assert.equal(game.steps, 0);
  assert.deepEqual(world.getColor(0, 1, 1), [0, 0, 0]);
  game.move(1, 0);
  game.reset();
  assert.equal(game.steps, 0);
  assert.deepEqual(game.player, { x: 1, y: 2, z: 1 });
  assert.deepEqual(game.playerColor, [0, 0, 0]);
  assert.ok(world.colors.every((v) => v === 0));
  assert.ok(world.scratch.every((v) => v === 0));
});

test('a black player walking on a black world preserves the black invariant', () => {
  const world = new VoxelWorld(3, 2, 3);
  const game = new GameState(world);
  for (let i = 0; i < 25; i++) {
    for (const direction of [[1, 0], [0, 1], [-1, 0], [0, -1]]) game.move(...direction);
  }
  assert.equal(game.steps, 100);
  assert.ok(world.colors.every((v) => v === 0));
});

test('choosing player RGB copies and validates it without changing voxels or steps', () => {
  const world = new VoxelWorld(3, 2, 3);
  const game = new GameState(world);
  const chosen = [255, 128, 64];
  game.setPlayerColor(chosen);
  chosen[0] = 0;
  assert.deepEqual(game.playerColor, [255, 128, 64]);
  assert.equal(game.steps, 0);
  assert.ok(world.colors.every((v) => v === 0));
  for (const invalid of [null, [1, 2], [-1, 0, 0], [256, 0, 0], [NaN, 0, 0], [Infinity, 0, 0]]) {
    assert.throws(() => game.setPlayerColor(invalid), RangeError);
  }
  assert.deepEqual(game.playerColor, [255, 128, 64]);
});

test('a move contributes the chosen RGB only at the destination standing voxel', () => {
  const world = new VoxelWorld(3, 2, 3);
  const game = new GameState(world);
  game.setPlayerColor([160, 80, 40]);
  game.move(1, 0);
  assert.deepEqual(world.getColor(2, 1, 1), [160 / 6, 80 / 6, 40 / 6].map((v) => Math.fround(v)));
  assert.deepEqual(world.getColor(1, 1, 1), [0, 0, 0]);
  assert.equal(Array.from(world.colors).filter((v) => v !== 0).length, 3);
  assert.deepEqual(game.player, { x: 2, y: 2, z: 1 });
  assert.equal(game.steps, 1);
});
