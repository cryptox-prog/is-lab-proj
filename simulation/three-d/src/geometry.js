import { Vector3, Quaternion, Matrix4, Box3, Ray, MathUtils } from 'three';

export const MODES = ['App only', 'App + privacy screen', 'App + fisheye', 'App + fisheye + privacy screen', 'App + radar', 'App + radar + privacy screen'];
export const defaults = () => ({mode: 1, phoneHeight: 1.2, phoneTilt: 30, phoneYaw: 0,
  cameraH: 75, cameraV: 60, privacyH: 60, bareH: 160, readableV: 160,
  fisheyeH: 120, fisheyeV: 90, radarH: 120, radarV: 70,
  radarX: -.6, radarY: .85, radarZ: -.2, radarYaw: 0, range: 2,
  occlusion: true, screenLOS: true, rays: true, volumes: true});

export function preset(name) {
  const owner = {id: 'owner', name: 'Owner', x: 0, z: .4, eye: 1.5};
  if (name === 'empty') return [owner];
  const observer = {id: 'observer-1', name: 'Observer 1', x: .30, z: .9, eye: 1.9};
  if (name === 'hidden') Object.assign(observer, {x: 0, eye: 1.5});
  if (name === 'lateral') Object.assign(observer, {x: .85, z: .6, eye: 1.5});
  return [owner, observer];
}

export function personMatrix(p) {
  const yaw = Math.atan2(p.x, p.z);
  return new Matrix4().compose(new Vector3(p.x, 0, p.z),
    new Quaternion().setFromAxisAngle(new Vector3(0, 1, 0), yaw), new Vector3(1, 1, 1));
}

export function bodyParts(p) {
  const legHeight = Math.max(.12, p.eye - .9);
  return [
    {name: 'head', center: [0, p.eye - .015, 0], size: [.19, .24, .19]},
    {name: 'torso', center: [0, p.eye - .49, 0], size: [.38, .68, .23]},
    {name: 'leg', center: [-.10, legHeight / 2, 0], size: [.15, legHeight, .19]},
    {name: 'leg', center: [.10, legHeight / 2, 0], size: [.15, legHeight, .19]},
  ];
}

export function facePoints(p) {
  const matrix = personMatrix(p), points = [];
  for (const y of [-.055, 0, .055]) for (const x of [-.05, 0, .05]) {
    points.push(new Vector3(x, p.eye + y, -.101).applyMatrix4(matrix));
  }
  return points;
}

export function phonePose(c) {
  const yaw = new Quaternion().setFromAxisAngle(new Vector3(0, 1, 0), MathUtils.degToRad(c.phoneYaw));
  const pitch = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -MathUtils.degToRad(c.phoneTilt));
  const rotation = yaw.multiply(pitch);
  const screen = new Vector3(0, c.phoneHeight, 0);
  const camera = new Vector3(0, .067, .012).applyQuaternion(rotation).add(screen);
  return {screen, camera, rotation};
}

export function inCoverage(point, origin, rotation, horizontal, vertical, range) {
  const d = point.clone().sub(origin).applyQuaternion(rotation.clone().invert());
  if (d.length() > range || d.length() < 1e-6) return false;
  const bearing = MathUtils.radToDeg(Math.atan2(d.x, d.z));
  const elevation = MathUtils.radToDeg(Math.atan2(d.y, Math.hypot(d.x, d.z)));
  return Math.abs(bearing) <= horizontal / 2 + 1e-8 && Math.abs(elevation) <= vertical / 2 + 1e-8;
}

// Three.js ray/box intersections in each person's local frame match the rendered blocks.
export function blockerBetween(origin, target, people, excludedId) {
  const length = origin.distanceTo(target);
  if (length < 1e-6) return null;
  const ray = new Ray(origin.clone(), target.clone().sub(origin).normalize());
  for (const person of people) {
    if (person.id === excludedId) continue;
    const localRay = ray.clone().applyMatrix4(personMatrix(person).invert());
    for (const part of bodyParts(person)) {
      const center = new Vector3(...part.center), half = new Vector3(...part.size).multiplyScalar(.5);
      const hit = localRay.intersectBox(new Box3(center.clone().sub(half), center.clone().add(half)), new Vector3());
      if (hit && hit.distanceTo(localRay.origin) < length - .002) return person.id;
    }
  }
  return null;
}

export function evaluate(c, people) {
  const pose = phonePose(c), wide = c.mode === 2 || c.mode === 3;
  const radarEnabled = c.mode >= 4, privacy = c.mode % 2 === 1;
  const radarOrigin = new Vector3(c.radarX, c.radarY, c.radarZ);
  const radarRotation = new Quaternion().setFromAxisAngle(new Vector3(0, 1, 0), MathUtils.degToRad(c.radarYaw));
  const screenTargets = [];
  for (const x of [-.026, 0, .026]) for (const y of [-.04, 0, .04]) {
    screenTargets.push(new Vector3(x, y, .013).applyQuaternion(pose.rotation).add(pose.screen));
  }
  const rows = people.map(p => {
    const samples = facePoints(p);
    const inCone = samples.map(point => inCoverage(point, pose.camera, pose.rotation,
      wide ? c.fisheyeH : c.cameraH, wide ? c.fisheyeV : c.cameraV, c.range));
    const visible = samples.map((point, i) => inCone[i] && (!c.occlusion || !blockerBetween(pose.camera, point, people, p.id)));
    // Majority of facial samples is a geometry heuristic, not a CV confidence score.
    const visibleSamples = visible.filter(Boolean).length;
    const optical = visibleSamples >= 5;
    const eye = samples[4];
    const readableAngle = inCoverage(eye, pose.screen, pose.rotation,
      privacy ? c.privacyH : c.bareH, c.readableV, c.range);
    const screenVisible = screenTargets.some(target => !blockerBetween(eye, target, people, p.id));
    const readable = readableAngle && (!c.screenLOS || screenVisible);
    const radar = radarEnabled && inCoverage(new Vector3(p.x, p.eye - .5, p.z), radarOrigin,
      radarRotation, c.radarH, c.radarV, c.range);
    const blocked = inCone.filter(Boolean).length >= 5 && !optical;
    return {id: p.id, name: p.name, optical, visibleSamples, blocked, readable, readableAngle,
      screenBlocked: readableAngle && !screenVisible, radar, face: eye.toArray(),
      rbu: p.id !== 'owner' && readable && !optical && !radar};
  });
  const faceCount = rows.filter(row => row.optical).length;
  const radarCount = rows.filter(row => row.radar).length;
  // Owner identity is designated ground truth; actual face recognition is not simulated.
  const trigger = rows.some(row => row.id !== 'owner' && row.optical) || (radarEnabled && radarCount > 1);
  rows.forEach(row => {row.breach = row.id !== 'owner' && row.readable && !trigger;});
  return {rows, trigger, faceCount, radarCount, breaches: rows.filter(row => row.breach).length};
}
