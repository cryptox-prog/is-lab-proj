import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { createIcons, RotateCcw, Camera, Box, ArrowDown, Video, UserPlus, Trash2 } from 'lucide';
import { defaults, preset, evaluate, personMatrix, bodyParts, phonePose, facePoints } from './geometry.js';
import './style.css';

createIcons({icons: {RotateCcw, Camera, Box, ArrowDown, Video, UserPlus, Trash2}});
const $ = id => document.getElementById(id);
let config = defaults(), people = preset('shoulder'), selected = 'observer-1', nextId = 2;
const host = $('scene'), scene = new THREE.Scene();
scene.background = new THREE.Color('#e6e9e8');
const renderer = new THREE.WebGLRenderer({antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
host.append(renderer.domElement);
const camera = new THREE.PerspectiveCamera(44, 1, .02, 60);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.minDistance = .2;
controls.maxDistance = 12;
controls.maxPolarAngle = Math.PI * .49;
scene.add(new THREE.HemisphereLight(0xffffff, 0x8d9698, 2.5));
const sunlight = new THREE.DirectionalLight(0xffffff, 2.8);
sunlight.position.set(-3, 6, 4);
scene.add(sunlight);
const floor = new THREE.Mesh(new THREE.PlaneGeometry(20, 20), new THREE.MeshStandardMaterial({color: '#e3e7e5', roughness: 1}));
floor.rotation.x = -Math.PI / 2;
floor.position.y = -.006;
scene.add(floor);
const grid = new THREE.GridHelper(8, 32, '#a6b4b3', '#ccd3d0');
scene.add(grid);
const content = new THREE.Group();
scene.add(content);
let picks = [], assessment, fields = new Map(), currentView = 'perspective';
const sightRay = new THREE.Raycaster(), pointer = new THREE.Vector2();
const ground = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
let drag = null;

function clearContent() {
  content.traverse(object => {
    object.geometry?.dispose();
    const materials = Array.isArray(object.material) ? object.material : [object.material];
    for (const mat of materials) {mat?.map?.dispose(); mat?.dispose();}
  });
  content.clear();
  picks = [];
}

function block(size, color, position, parent = content) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(...size), new THREE.MeshStandardMaterial({color, roughness: .85}));
  mesh.position.set(...position);
  parent.add(mesh);
  return mesh;
}

function label(text, position, color = '#303a3c') {
  const canvas = document.createElement('canvas');
  canvas.width = 384; canvas.height = 80;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#ffffffee'; ctx.fillRect(0, 0, 384, 80);
  ctx.fillStyle = color; ctx.font = '600 30px Arial'; ctx.textAlign = 'center'; ctx.fillText(text, 192, 51);
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(canvas), depthTest: false}));
  sprite.position.copy(position); sprite.scale.set(.42, .0875, 1);
  sprite.visible = currentView !== 'camera';
  content.add(sprite);
}

function line(points, color, opacity = 1) {
  const l = new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),
    new THREE.LineBasicMaterial({color, transparent: true, opacity, depthWrite: false}));
  content.add(l);
}

function volume(origin, rotation, h, v, color) {
  const sample = (az, el) => {
    const a = THREE.MathUtils.degToRad(az), e = THREE.MathUtils.degToRad(el);
    return new THREE.Vector3(Math.sin(a) * Math.cos(e), Math.sin(e), Math.cos(a) * Math.cos(e))
      .multiplyScalar(config.range).applyQuaternion(rotation).add(origin);
  };
  const columns = 36, rows = 16, positions = [], indices = [];
  for (let j = 0; j <= rows; j++) for (let i = 0; i <= columns; i++) positions.push(...sample(-h / 2 + h * i / columns, -v / 2 + v * j / rows).toArray());
  for (let j = 0; j < rows; j++) for (let i = 0; i < columns; i++) {
    const k = j * (columns + 1) + i;
    indices.push(k, k + 1, k + columns + 1, k + 1, k + columns + 2, k + columns + 1);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3)); geometry.setIndex(indices);
  const shell = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({color, transparent: true, opacity: .035, side: THREE.DoubleSide, depthWrite: false}));
  content.add(shell);
  for (const el of [-v / 2, 0, v / 2]) {
    const arc = Array.from({length: columns + 1}, (_, i) => sample(-h / 2 + h * i / columns, el));
    line(arc, color, .32);
    if (el !== 0) {line([origin, arc[0]], color, .3); line([origin, arc.at(-1)], color, .3);}
  }
  for (const az of [-h / 2, h / 2]) line(Array.from({length: rows + 1}, (_, i) => sample(az, -v / 2 + v * i / rows)), color, .32);
}

function drawPhone(pose) {
  const group = new THREE.Group(); group.position.copy(pose.screen); group.quaternion.copy(pose.rotation); content.add(group);
  block([.083, .164, .014], '#242b30', [0, 0, 0], group);
  const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 512;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = assessment.trigger ? '#481024' : '#d0ebe0'; ctx.fillRect(0, 0, 256, 512);
  ctx.fillStyle = assessment.trigger ? '#ff3159' : '#244b42'; ctx.font = 'bold 36px Arial'; ctx.textAlign = 'center';
  ctx.fillText(assessment.trigger ? 'LOCKED' : 'PrivaSc', 128, 195);
  if (!assessment.trigger) for (let y = 245; y < 400; y += 24) ctx.fillRect(35, y, 186, 5);
  const display = new THREE.Mesh(new THREE.PlaneGeometry(.07, .138), new THREE.MeshBasicMaterial({map: new THREE.CanvasTexture(canvas)}));
  display.position.z = .008; group.add(display);
  block([.007, .007, .003], '#13191c', [0, .067, .01], group);
  label('PHONE', pose.screen.clone().add(new THREE.Vector3(-.19, .03, 0)));
  line([new THREE.Vector3(0, 0, 0), pose.screen], '#6c7d7d', .5);
}

function rebuild() {
  assessment = evaluate(config, people);
  clearContent();
  const pose = phonePose(config);
  drawPhone(pose);
  for (const p of people) {
    const row = assessment.rows.find(r => r.id === p.id);
    const group = new THREE.Group(); group.applyMatrix4(personMatrix(p)); content.add(group);
    const color = p.id === 'owner' ? '#397f83' : row.breach ? '#eb284f' : row.optical || row.radar ? '#c89832' : '#8d969a';
    for (const part of bodyParts(p)) {
      const body = block(part.size, part.name === 'head' ? '#d7b8a5' : color, part.center, group);
      body.userData.person = p.id; picks.push(body);
    }
    block([.14, .14, .005], row.optical ? '#f5d476' : '#ebe5de', [0, p.eye, -.098], group);
    for (const x of [-.035, .035]) block([.015, .012, .004], '#303538', [x, p.eye + .025, -.102], group);
    label(p.name + (p.id === selected ? ' *' : ''), new THREE.Vector3(p.x, p.eye + .21, p.z));
    if (p.id === selected) {
      const selection = new THREE.BoxHelper(group, '#ff1744'); content.add(selection);
    }
    if (config.rays) line([pose.camera, new THREE.Vector3(...row.face)], row.optical ? '#21936f' : row.blocked ? '#e63854' : '#849aab', .9);
  }
  if (config.volumes) {
    const wide = config.mode === 2 || config.mode === 3;
    volume(pose.camera, pose.rotation, wide ? config.fisheyeH : config.cameraH, wide ? config.fisheyeV : config.cameraV, '#159bb2');
    volume(pose.screen, pose.rotation, config.mode % 2 ? config.privacyH : config.bareH, config.readableV, '#38a16b');
  }
  if (config.mode >= 4) {
    const origin = new THREE.Vector3(config.radarX, config.radarY, config.radarZ);
    const rotation = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), THREE.MathUtils.degToRad(config.radarYaw));
    const radar = new THREE.Group(); radar.position.copy(origin); radar.quaternion.copy(rotation); content.add(radar);
    block([.085, .045, .025], '#8555a4', [0, 0, 0], radar);
    label('RADAR', origin.clone().add(new THREE.Vector3(0, .1, 0)), '#8555a4');
    line([new THREE.Vector3(origin.x, 0, origin.z), origin], '#8555a4', .6);
    if (config.volumes) volume(origin, rotation, config.radarH, config.radarV, '#9558bc');
  }
  $('faces').value = assessment.faceCount;
  $('targets').value = config.mode >= 4 ? assessment.radarCount : '—';
  $('breaches').value = assessment.breaches;
  const status = $('status');
  status.textContent = assessment.trigger ? 'PROTECTED' : assessment.breaches ? 'EXPOSED' : 'CLEAR';
  status.style.borderColor = assessment.trigger ? '#ff1744' : assessment.breaches ? '#eda132' : '#67b596';
  $('detail').textContent = assessment.trigger ? 'Detected observer or radar count > 1.' : assessment.breaches ? 'Readable observer without a protection trigger.' : 'No current readable, unprotected observer.';
  $('results').replaceChildren(...assessment.rows.map(row => {
    const tr = document.createElement('tr');
    for (const text of [row.name, row.optical ? `Visible ${row.visibleSamples}/9` : row.blocked ? `Blocked ${row.visibleSamples}/9` : 'Outside',
      row.readable ? 'Yes' : row.screenBlocked ? 'Blocked' : 'No', config.mode >= 4 ? row.radar ? 'Yes' : 'No' : '—']) {
      const td = document.createElement('td'); td.textContent = text; tr.append(td);
    }
    return tr;
  }));
  $('radar-controls').hidden = config.mode < 4;
  window.simulatorState = {config: structuredClone(config), people: structuredClone(people), assessment: structuredClone(assessment)};
}

function field(parent, key, name, min, max, step, get, set) {
  const wrapper = document.createElement('div'); wrapper.className = 'field';
  const labelElement = document.createElement('label'); labelElement.textContent = name; labelElement.htmlFor = `${key}-number`;
  const number = document.createElement('input'); number.type = 'number'; number.id = `${key}-number`;
  const slider = document.createElement('input'); slider.type = 'range'; slider.setAttribute('aria-label', name);
  for (const input of [number, slider]) {input.min = min; input.max = max; input.step = step;}
  const refresh = () => {number.value = get(); slider.value = get();};
  const changed = event => {
    if (event.target.value === '' || !Number.isFinite(Number(event.target.value))) return;
    set(Math.min(max, Math.max(min, Number(event.target.value)))); refresh(); rebuild();
    if (currentView === 'camera') setView('camera');
  };
  number.addEventListener('input', changed); slider.addEventListener('input', changed);
  wrapper.append(labelElement, number, slider); parent.append(wrapper); refresh(); fields.set(key, refresh);
}

function selection() {
  $('selected').replaceChildren(...people.map(p => new Option(p.name, p.id)));
  if (!people.some(p => p.id === selected)) selected = people[0].id;
  $('selected').value = selected;
  $('person-controls').replaceChildren();
  const person = () => people.find(p => p.id === selected);
  field($('person-controls'), 'person-x', 'Lateral X (m)', -1.6, 1.6, .01, () => person().x, v => person().x = v);
  field($('person-controls'), 'person-z', 'Distance Z (m)', .2, 2, .01, () => person().z, v => person().z = v);
  field($('person-controls'), 'person-eye', 'Eye height (m)', .9, 2.1, .01, () => person().eye, v => person().eye = v);
  $('remove').disabled = selected === 'owner';
}

const phoneFields = [['phoneHeight','Phone height (m)',.7,1.7,.01], ['phoneTilt','Phone tilt (deg)',-30,65,1], ['phoneYaw','Phone yaw (deg)',-90,90,1],
  ['cameraH','Camera horizontal (deg)',30,110,1], ['cameraV','Camera vertical (deg)',30,110,1], ['privacyH','Privacy readable (deg)',20,100,1],
  ['fisheyeH','Fisheye effective H (deg)',60,210,1], ['fisheyeV','Fisheye effective V (deg)',40,150,1], ['range','Sensor / reading range (m)',.5,5,.1]];
for (const [key, name, min, max, step] of phoneFields) field($('phone-controls'), key, name, min, max, step, () => config[key], v => config[key] = v);
for (const [key,name,min,max,step] of [['radarX','Radar X (m)',-2,2,.05],['radarY','Radar height (m)',.2,1.8,.05],['radarZ','Radar Z (m)',-1,2,.05],['radarYaw','Radar yaw (deg)',-180,180,1]]) {
  field($('radar-inputs'), key, name, min, max, step, () => config[key], v => config[key] = v);
}

function setView(view) {
  currentView = view;
  controls.maxPolarAngle = view === 'camera' ? Math.PI - .01 : Math.PI * .49;
  const pose = phonePose(config);
  if (view === 'top') {camera.position.set(.01, 4.8, .6); controls.target.set(0, 0, .6); camera.fov = 44;}
  else if (view === 'camera') {
    camera.position.copy(pose.camera);
    controls.target.copy(new THREE.Vector3(0,0,1).applyQuaternion(pose.rotation).add(pose.camera));
    camera.fov = config.mode === 2 || config.mode === 3 ? 90 : config.cameraV;
  } else {camera.position.set(3, 2.4, -2.2); controls.target.set(0, 1.05, .55); camera.fov = 44;}
  camera.updateProjectionMatrix(); controls.update();
  content.traverse(object => {if (object.isSprite) object.visible = view !== 'camera';});
}

$('mode').addEventListener('change', e => {config.mode = Number(e.target.value); rebuild(); if (currentView === 'camera') setView('camera');});
$('preset').addEventListener('change', e => {people = preset(e.target.value); selected = people.at(-1).id; selection(); rebuild();});
$('selected').addEventListener('change', e => {selected = e.target.value; selection(); rebuild();});
$('add').addEventListener('click', () => {
  const id = nextId++; people.push({id: `observer-${id}`, name: `Observer ${id}`, x: .4, z: .8, eye: 1.7}); selected = people.at(-1).id; selection(); rebuild();
});
$('remove').addEventListener('click', () => {if (selected === 'owner') return; people = people.filter(p => p.id !== selected); selected = 'owner'; selection(); rebuild();});
$('reset').addEventListener('click', () => {
  config = defaults(); people = preset('shoulder'); selected = 'observer-1'; nextId = 2;
  $('mode').value = config.mode; $('preset').value = 'shoulder';
  for (const [id,key] of [['occlusion','occlusion'],['screen-los','screenLOS'],['rays','rays'],['volumes','volumes']]) $(id).checked = config[key];
  for (const refresh of fields.values()) refresh(); selection(); rebuild(); setView('perspective');
});
for (const [id,key] of [['occlusion','occlusion'],['screen-los','screenLOS'],['rays','rays'],['volumes','volumes']]) $(id).addEventListener('change', e => {config[key] = e.target.checked; rebuild();});
document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => setView(button.dataset.view)));
$('capture').addEventListener('click', () => {
  renderer.render(scene, camera); const a = document.createElement('a'); a.download = 'privasc-3d-scene.png'; a.href = renderer.domElement.toDataURL('image/png'); a.click();
});

function pointerRay(event) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1);
  sightRay.setFromCamera(pointer, camera);
}
renderer.domElement.addEventListener('pointerdown', event => {
  if (event.button !== 0) return;
  pointerRay(event); scene.updateMatrixWorld(true);
  const hit = sightRay.intersectObjects(picks)[0];
  if (!hit) return;
  const point = sightRay.ray.intersectPlane(ground, new THREE.Vector3());
  if (!point) return;
  selected = hit.object.userData.person;
  const p = people.find(p => p.id === selected);
  drag = {id: selected, offset: point.clone().sub(new THREE.Vector3(p.x, 0, p.z))};
  controls.enabled = false; renderer.domElement.setPointerCapture(event.pointerId); selection(); rebuild();
});
renderer.domElement.addEventListener('pointermove', event => {
  if (!drag) return; pointerRay(event);
  const point = sightRay.ray.intersectPlane(ground, new THREE.Vector3());
  if (!point) return;
  point.sub(drag.offset); const p = people.find(p => p.id === drag.id);
  p.x = Number(THREE.MathUtils.clamp(point.x, -1.6, 1.6).toFixed(2)); p.z = Number(THREE.MathUtils.clamp(point.z, .2, 2).toFixed(2));
  fields.get('person-x')(); fields.get('person-z')(); rebuild();
});
function endDrag() {drag = null; controls.enabled = true;}
renderer.domElement.addEventListener('pointerup', endDrag);
renderer.domElement.addEventListener('pointercancel', endDrag);
renderer.domElement.addEventListener('webglcontextlost', e => {e.preventDefault(); $('scene-error').hidden = false; $('scene-error').textContent = '3D graphics context lost. Reload this page.';});
new ResizeObserver(() => {
  const {width,height} = host.getBoundingClientRect(); renderer.setSize(width,height); camera.aspect = width / height; camera.updateProjectionMatrix();
}).observe(host);
$('mode').value = String(config.mode);
selection(); rebuild(); setView('perspective');
renderer.setAnimationLoop(() => {controls.update(); renderer.render(scene, camera);});
