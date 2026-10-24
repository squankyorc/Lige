import test from 'node:test';
import assert from 'node:assert/strict';
import { displayColorScale } from '../src/display-color.js';

test('black remains exactly black when faint colors are revealed', () => {
  const scale = displayColorScale(0, 0, 0);
  assert.equal(scale, 1);
  assert.equal(0 * scale, 0);
});

test('exact display mode leaves all channel values unchanged', () => {
  for (const rgb of [[0, 0, 0], [12.5, 12.5, 12.5], [10, 100, 200], [255, 255, 255]]) {
    const scale = displayColorScale(...rgb, false);
    assert.equal(scale, 1);
    assert.deepEqual(rgb.map((channel) => channel * scale), rgb);
  }
});

test('a first step with RGB 100 reveals the 12.5 channel value more visibly', () => {
  const value = 100 / 8;
  const scale = displayColorScale(value, value, value);
  const displayed = value * scale;
  assert.ok(Math.abs(displayed - 255 * (value / 255) ** 0.25) < 1e-12);
  assert.ok(displayed > 119 && displayed < 121);
  assert.ok(displayed > value);
});

test('revealing faint color preserves channel ratios and never clips', () => {
  for (const rgb of [[1, 2, 4], [12.5, 3.125, 0], [2, 100, 20], [0.25, 0.125, 0.0625]]) {
    const scale = displayColorScale(...rgb);
    const displayed = rgb.map((channel) => channel * scale);
    assert.ok(displayed.every((channel) => channel >= 0 && channel <= 255));
    for (let channel = 0; channel < 3; channel++) {
      if (rgb[channel] === 0) assert.equal(displayed[channel], 0);
      else assert.ok(Math.abs(displayed[channel] / displayed[0] - rgb[channel] / rgb[0]) < 1e-12);
    }
    const peak = Math.max(...rgb);
    assert.ok(Math.abs(Math.max(...displayed) - 255 * (peak / 255) ** 0.25) < 1e-12);
  }
});

test('a full-intensity peak has scale one', () => {
  for (const rgb of [[255, 0, 0], [0, 255, 80], [20, 40, 255], [255, 255, 255]]) {
    assert.equal(displayColorScale(...rgb), 1);
  }
});

test('very small stored Float32 values produce finite deterministic scales', () => {
  for (const value of [Math.fround(1e-20), Math.fround(1e-38), 2 ** -149]) {
    const scale = displayColorScale(value, value / 2, 0);
    assert.ok(Number.isFinite(scale));
    assert.ok(Number.isFinite(value * scale));
    assert.ok(value * scale > 0);
    assert.equal(displayColorScale(value, value / 2, 0), scale);
  }
});
