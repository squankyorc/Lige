import './style.css';
import { VoxelWorld } from './simulation.js';
import { GameState } from './game-state.js';
import { createWorldView } from './view.js';

const $ = (id) => document.getElementById(id);
const world = new VoxelWorld(16, 5, 16);
const game = new GameState(world);
let selected = { x: game.player.x, y: world.height - 1, z: game.player.z };
let playing = false;
let started = false;
let view;
const channelIds = ['color-r', 'color-g', 'color-b'];
const coordinateIds = ['voxel-x', 'voxel-y', 'voxel-z'];
const coordinateKeys = ['x', 'y', 'z'];

function announce(message) { $('status').textContent = message; }
function colorHex(rgb) { return `#${rgb.map((c) => c.toString(16).padStart(2, '0')).join('')}`; }
function setPlayerColor(rgb) {
  game.setPlayerColor(rgb);
  channelIds.forEach((id, i) => { $(id).value = String(rgb[i]); $(id).setCustomValidity(''); });
  $('color-picker').value = colorHex(rgb);
  document.querySelectorAll('[data-color]').forEach((button) => {
    button.setAttribute('aria-pressed', String(button.dataset.color.toLowerCase() === colorHex(rgb)));
  });
  view?.update(game.player, selected, game.playerColor);
  announce(`Player color set to RGB ${rgb.join(', ')}. Take a step to add it beneath you, or paint a voxel.`);
}
function renderState() {
  $('step-count').textContent = String(game.steps).padStart(3, '0');
  $('player-position').textContent = `${game.player.x}, ${game.player.z}`;
  coordinateIds.forEach((id, i) => { $(id).value = selected[coordinateKeys[i]]; });
  const rgb = world.getColor(selected.x, selected.y, selected.z);
  $('selected-rgb').textContent = `RGB ${rgb.map((c) => c.toFixed(2)).join(' / ')}`;
  let lit = 0;
  for (let i = 0; i < world.colors.length; i += 3) {
    if (world.colors[i] > 0 || world.colors[i + 1] > 0 || world.colors[i + 2] > 0) lit++;
  }
  $('world-summary').textContent = `${lit.toLocaleString()} / ${world.size.toLocaleString()} voxels carry color`;
  $('world-summary').dataset.colored = String(lit);
  $('home-state').textContent = started ? `Your world is waiting. ${game.steps} steps taken.` : 'Every voxel starts pure black. The first color is yours.';
  for (const button of document.querySelectorAll('[data-move]')) {
    const [dx, dz] = button.dataset.move.split(',').map(Number);
    button.disabled = !world.contains(game.player.x + dx, 0, game.player.z + dz);
  }
  view?.update(game.player, selected, game.playerColor);
}
function selectVoxel(coords) {
  selected = { x: coords.x, y: coords.y, z: coords.z };
  renderState();
  announce(`Selected voxel ${selected.x}, ${selected.y}, ${selected.z}.`);
}
function move(dx, dz) {
  if (!playing) return;
  if (!game.move(dx, dz)) {
    announce('World edge. That move did not take a step.');
    return;
  }
  selected = { x: game.player.x, y: world.height - 1, z: game.player.z };
  renderState();
  announce(`Step ${game.steps}. Averaged all ${world.size.toLocaleString()} voxels. Position ${game.player.x}, ${game.player.z}.`);
}
function paint(target) {
  world.setColor(target.x, target.y, target.z, game.playerColor);
  selected = { ...target };
  renderState();
  announce(`Painted voxel ${target.x}, ${target.y}, ${target.z} with RGB ${game.playerColor.join(', ')}. No step taken.`);
}
$('start-game').addEventListener('click', () => {
  playing = true;
  started = true;
  $('home-screen').hidden = true;
  $('game-screen').hidden = false;
  document.querySelector('.skip-link').setAttribute('href', '#viewport');
  window.scrollTo({ top: 0, behavior: 'instant' });
  $('start-game').textContent = 'Resume world';
  if (!view) {
    try { view = createWorldView($('viewport'), world, selectVoxel); }
    catch (error) {
      const fallback = document.createElement('p');
      fallback.className = 'graphics-error';
      fallback.textContent = '3D graphics need a browser with WebGL2 enabled. You can still explore with movement, coordinates, and RGB readouts.';
      $('viewport').prepend(fallback);
      console.error('Could not initialize 3D view:', error);
    }
  }
  renderState();
  view?.resize();
  $('viewport').focus({ preventScroll: true });
});
$('go-home').addEventListener('click', () => {
  playing = false;
  $('game-screen').hidden = true;
  $('home-screen').hidden = false;
  document.querySelector('.skip-link').setAttribute('href', '#main-content');
  window.scrollTo({ top: 0, behavior: 'instant' });
  $('start-game').focus({ preventScroll: true });
});
$('viewport').addEventListener('view-error', (event) => announce(event.detail));
$('color-picker').addEventListener('input', (event) => {
  const hex = event.target.value;
  setPlayerColor([1, 3, 5].map((offset) => Number.parseInt(hex.slice(offset, offset + 2), 16)));
});
for (const id of channelIds) {
  $(id).addEventListener('change', () => {
    const rgb = channelIds.map((channel) => $(channel).valueAsNumber);
    if (rgb.some((c) => !Number.isInteger(c) || c < 0 || c > 255)) {
      $(id).setCustomValidity('Enter whole RGB values from 0 to 255.');
      $(id).reportValidity();
      return;
    }
    setPlayerColor(rgb);
  });
  $(id).addEventListener('input', () => {
    $(id).setCustomValidity('');
    const rgb = channelIds.map((channel) => $(channel).valueAsNumber);
    if (rgb.every((c) => Number.isInteger(c) && c >= 0 && c <= 255)) setPlayerColor(rgb);
  });
}
document.querySelectorAll('[data-color]').forEach((button) => button.addEventListener('click', () => {
  const hex = button.dataset.color;
  setPlayerColor([1, 3, 5].map((offset) => Number.parseInt(hex.slice(offset, offset + 2), 16)));
}));
document.querySelectorAll('[data-move]').forEach((button) => button.addEventListener('click', () => move(...button.dataset.move.split(',').map(Number))));
$('select-voxel').addEventListener('click', () => {
  const values = coordinateIds.map((id) => $(id).valueAsNumber);
  if (!world.contains(...values)) {
    announce('Use whole coordinates: X and Z 0–15; Y 0–4.');
    return;
  }
  selectVoxel(Object.fromEntries(coordinateKeys.map((key, i) => [key, values[i]])));
});
$('paint-selected').addEventListener('click', () => paint(selected));
$('paint-below').addEventListener('click', () => paint({ x: game.player.x, y: world.height - 1, z: game.player.z }));
$('visible-layers').addEventListener('input', (event) => {
  const layers = Number(event.target.value);
  $('layer-value').textContent = `${layers} / ${world.height}`;
  view?.setLayers(layers);
});
$('reveal-faint').addEventListener('change', (event) => {
  view?.setRevealFaint(event.target.checked);
  announce(event.target.checked
    ? 'Faint colors brightened in the view. Stored RGB values and step count are unchanged.'
    : 'Showing exact RGB brightness. Stored values and step count are unchanged.');
});
$('reset-world').addEventListener('click', () => {
  game.reset();
  setPlayerColor([0, 0, 0]);
  selected = { x: game.player.x, y: world.height - 1, z: game.player.z };
  $('visible-layers').value = String(world.height);
  $('layer-value').textContent = `${world.height} / ${world.height}`;
  view?.setLayers(world.height);
  renderState();
  announce('World reset. All voxels and the player color are pure black.');
});
$('camera-reset').addEventListener('click', () => view?.resetCamera());
$('camera-left').addEventListener('click', () => view?.rotate(Math.PI / 8));
$('camera-right').addEventListener('click', () => view?.rotate(-Math.PI / 8));
$('camera-in').addEventListener('click', () => view?.zoom(0.85));
$('camera-out').addEventListener('click', () => view?.zoom(1.15));
window.addEventListener('keydown', (event) => {
  if (!playing || event.altKey || event.ctrlKey || event.metaKey) return;
  if (event.target.closest('input, textarea, select, summary, [contenteditable="true"]')) return;
  const directions = { w: [0, -1], ArrowUp: [0, -1], a: [-1, 0], ArrowLeft: [-1, 0], s: [0, 1], ArrowDown: [0, 1], d: [1, 0], ArrowRight: [1, 0] };
  const direction = directions[event.key] || directions[event.key.toLowerCase()];
  if (direction || event.key.toLowerCase() === 'p') {
    event.preventDefault();
    if (event.repeat) return;
    if (direction) move(...direction);
    else paint({ x: game.player.x, y: world.height - 1, z: game.player.z });
  }
});
renderState();
