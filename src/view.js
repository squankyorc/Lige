import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { displayColorScale } from './display-color.js';

// Rendering has no simulation clock: the world changes only through game actions.
export function createWorldView(container, world, onSelect) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setClearColor(0x101518);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.domElement.setAttribute('aria-label', 'Voxel volume. Drag to orbit; scroll to zoom. Select a voxel with a click or the coordinate controls.');
  container.prepend(renderer.domElement);
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(39, 1, 0.1, 180);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.target.set(0, world.height * 0.4, 0);
  controls.minDistance = 12;
  controls.maxDistance = 90;
  controls.maxPolarAngle = Math.PI * 0.48;
  controls.enablePan = false;
  const render = () => renderer.render(scene, camera);
  controls.addEventListener('change', render);

  const spacing = 1.03;
  const position = (x, y, z) => new THREE.Vector3(
    (x - (world.width - 1) / 2) * spacing,
    (y + 0.5) * spacing,
    (z - (world.depth - 1) / 2) * spacing,
  );
  const geometry = new THREE.BoxGeometry(0.96, 0.96, 0.96);
  const material = new THREE.MeshBasicMaterial({ color: 0xffffff });
  const voxels = new THREE.InstancedMesh(geometry, material, world.size);
  voxels.instanceMatrix.setUsage(THREE.StaticDrawUsage);
  const ids = [];
  const matrix = new THREE.Matrix4();
  const color = new THREE.Color();
  const edgeGeometry = new THREE.EdgesGeometry(geometry);
  const edgeTemplate = edgeGeometry.getAttribute('position');
  const edgePositions = new Float32Array(edgeTemplate.count * world.size * 3);
  // Y-major render order permits a cutaway using instance count / draw range.
  for (let y = 0; y < world.height; y++) {
    for (let z = 0; z < world.depth; z++) {
      for (let x = 0; x < world.width; x++) {
        const id = ids.length;
        const p = position(x, y, z);
        ids.push({ x, y, z, index: world.index(x, y, z) });
        matrix.makeTranslation(p.x, p.y, p.z);
        voxels.setMatrixAt(id, matrix);
        voxels.setColorAt(id, color.setRGB(0, 0, 0));
        for (let v = 0; v < edgeTemplate.count; v++) {
          const offset = (id * edgeTemplate.count + v) * 3;
          edgePositions[offset] = edgeTemplate.getX(v) + p.x;
          edgePositions[offset + 1] = edgeTemplate.getY(v) + p.y;
          edgePositions[offset + 2] = edgeTemplate.getZ(v) + p.z;
        }
      }
    }
  }
  edgeGeometry.dispose();
  voxels.computeBoundingSphere();
  scene.add(voxels);
  const linesGeometry = new THREE.BufferGeometry();
  linesGeometry.setAttribute('position', new THREE.BufferAttribute(edgePositions, 3));
  const lines = new THREE.LineSegments(linesGeometry, new THREE.LineBasicMaterial({ color: 0x344045, transparent: true, opacity: 0.57 }));
  scene.add(lines);
  const ground = new THREE.GridHelper(28, 28, 0x394447, 0x222d30);
  ground.position.y = -0.06;
  scene.add(ground);

  const selection = new THREE.LineSegments(
    new THREE.EdgesGeometry(new THREE.BoxGeometry(1.005, 1.005, 1.005)),
    new THREE.LineBasicMaterial({ color: 0xc9fa73, depthTest: false }),
  );
  selection.renderOrder = 5;
  scene.add(selection);
  const marker = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.16, 0.32, 4, 8), new THREE.MeshBasicMaterial({ color: 0xffffff, depthTest: false }));
  marker.add(body);
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.29, 0.36, 24), new THREE.MeshBasicMaterial({ color: 0xffffff, side: THREE.DoubleSide, depthTest: false }));
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = -0.43;
  marker.add(ring);
  marker.renderOrder = 6;
  scene.add(marker);
  let visibleLayers = world.height;
  let revealFaint = true;
  let selected = { x: 8, y: 4, z: 8 };
  const raycaster = new THREE.Raycaster();
  const mouse = new THREE.Vector2();
  let pointerDown;
  renderer.domElement.addEventListener('pointerdown', (event) => {
    pointerDown = { x: event.clientX, y: event.clientY };
  });
  renderer.domElement.addEventListener('pointerup', (event) => {
    if (!pointerDown || Math.hypot(event.clientX - pointerDown.x, event.clientY - pointerDown.y) > 5) return;
    pointerDown = null;
    const bounds = renderer.domElement.getBoundingClientRect();
    mouse.set(((event.clientX - bounds.left) / bounds.width) * 2 - 1, -((event.clientY - bounds.top) / bounds.height) * 2 + 1);
    raycaster.setFromCamera(mouse, camera);
    const hit = raycaster.intersectObject(voxels)[0];
    if (hit?.instanceId !== undefined) onSelect(ids[hit.instanceId]);
  });
  let lastAspect = 0;
  const resize = () => {
    const { width, height } = container.getBoundingClientRect();
    if (width < 1 || height < 1) return;
    renderer.setSize(width, height);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    if (Math.abs(camera.aspect - lastAspect) > 0.01) {
      // Fit the full volume when the viewport changes between wide and narrow.
      const halfVertical = THREE.MathUtils.degToRad(camera.fov / 2);
      const halfHorizontal = Math.atan(Math.tan(halfVertical) * camera.aspect);
      const radius = Math.hypot(world.width, world.height, world.depth) * spacing / 2;
      const distance = Math.min(controls.maxDistance, radius * 1.08 / Math.sin(Math.min(halfVertical, halfHorizontal)));
      const direction = camera.position.clone().sub(controls.target).normalize();
      camera.position.copy(controls.target).addScaledVector(direction, distance);
      lastAspect = camera.aspect;
      controls.update();
    }
    render();
  };
  new ResizeObserver(resize).observe(container);
  renderer.domElement.addEventListener('webglcontextlost', (event) => {
    event.preventDefault();
    container.dispatchEvent(new CustomEvent('view-error', { detail: '3D graphics were interrupted. Reload to restore the view. Your coordinate and movement controls still work.' }));
  });
  function resetCamera() {
    camera.position.set(23, 22, 25);
    controls.target.set(0, world.height * 0.4, 0);
    lastAspect = 0;
    controls.update();
    resize();
  }
  resetCamera();
  function updateColors() {
    for (let id = 0; id < ids.length; id++) {
      const offset = ids[id].index * 3;
      const r = world.colors[offset];
      const g = world.colors[offset + 1];
      const b = world.colors[offset + 2];
      const scale = displayColorScale(r, g, b, revealFaint) / 255;
      color.setRGB(r * scale, g * scale, b * scale, THREE.SRGBColorSpace);
      voxels.setColorAt(id, color);
    }
    voxels.instanceColor.needsUpdate = true;
  }
  return {
    update(player, target, playerColor = [0, 0, 0]) {
      selected = target;
      updateColors();
      selection.position.copy(position(target.x, target.y, target.z));
      selection.visible = target.y < visibleLayers;
      marker.position.copy(position(player.x, world.height, player.z));
      body.material.color.setRGB(playerColor[0] / 255, playerColor[1] / 255, playerColor[2] / 255, THREE.SRGBColorSpace);
      render();
    },
    setRevealFaint(enabled) {
      revealFaint = enabled;
      updateColors();
      render();
    },
    setLayers(layers) {
      visibleLayers = layers;
      const count = world.width * world.depth * layers;
      voxels.count = count;
      linesGeometry.setDrawRange(0, count * edgeTemplate.count);
      selection.visible = selected.y < layers;
      render();
    },
    resetCamera,
    resize,
    rotate(angle) {
      const delta = camera.position.clone().sub(controls.target);
      delta.applyAxisAngle(new THREE.Vector3(0, 1, 0), angle);
      camera.position.copy(controls.target).add(delta);
      controls.update();
    },
    zoom(factor) {
      const delta = camera.position.clone().sub(controls.target);
      delta.multiplyScalar(factor).clampLength(controls.minDistance, controls.maxDistance);
      camera.position.copy(controls.target).add(delta);
      controls.update();
    },
  };
}
