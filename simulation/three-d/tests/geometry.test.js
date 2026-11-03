import test from 'node:test';
import assert from 'node:assert/strict';
import { Vector3, Quaternion } from 'three';
import { defaults, preset, evaluate, inCoverage, blockerBetween } from '../src/geometry.js';

test('Owner only is not a privacy threat', () => {
  const r = evaluate(defaults(), preset('empty'));
  assert.equal(r.faceCount, 1); assert.equal(r.trigger, false); assert.equal(r.breaches, 0);
});
test('Over-shoulder face is partially visible and triggers protection', () => {
  const r = evaluate(defaults(), preset('shoulder'));
  assert.equal(r.faceCount, 2); assert.equal(r.rows[1].optical, true);
  assert.ok(r.rows[1].visibleSamples >= 5); assert.equal(r.rows[1].readable, true); assert.equal(r.trigger, true);
});
test('Aligned occluded person cannot see the screen either', () => {
  const r = evaluate(defaults(), preset('hidden'));
  assert.equal(r.rows[1].optical, false); assert.equal(r.rows[1].blocked, true);
  assert.equal(r.rows[1].screenBlocked, true); assert.equal(r.rows[1].readable, false);
  assert.equal(r.breaches, 0); assert.equal(r.trigger, false);
});
test('Disabling body occlusion detects the central face', () => {
  const c = defaults(); c.occlusion = false;
  const r = evaluate(c, preset('hidden')); assert.equal(r.faceCount, 2); assert.equal(r.trigger, true);
});
test('Conservative screen-readability option is distinct from camera visibility', () => {
  const c = defaults(); c.screenLOS = false;
  const r = evaluate(c, preset('hidden'));
  assert.equal(r.rows[1].readable, true); assert.equal(r.rows[1].optical, false); assert.equal(r.breaches, 1);
});
test('Raising a face above a lower owner removes physical blockage', () => {
  const people = preset('hidden'); people[0].eye = 1.25; people[1].eye = 1.9;
  const r = evaluate(defaults(), people); assert.equal(r.rows[1].optical, true); assert.equal(r.trigger, true);
});
test('Lateral readable blind spot exists without the privacy filter', () => {
  const c = defaults(); c.mode = 0;
  const r = evaluate(c, preset('lateral'));
  assert.equal(r.rows[1].optical, false); assert.equal(r.rows[1].readable, true); assert.equal(r.breaches, 1);
});
test('Privacy filter removes lateral readability', () => {
  const r = evaluate(defaults(), preset('lateral')); assert.equal(r.rows[1].readable, false); assert.equal(r.breaches, 0);
});
test('All six modes evaluate without changing identity or count rules', () => {
  for (let mode = 0; mode < 6; mode++) {
    const c = defaults(); c.mode = mode;
    const r = evaluate(c, preset('shoulder'));
    assert.equal(r.trigger, true); assert.equal(r.rows.length, 2);
    if (mode < 4) assert.equal(r.radarCount, 0);
  }
});
test('Radar count greater than one triggers even with an optically hidden face', () => {
  const c = defaults(); c.mode = 4;
  const r = evaluate(c, preset('hidden'));
  assert.equal(r.faceCount, 1); assert.equal(r.radarCount, 2); assert.equal(r.trigger, true);
});
test('One radar target alone is not a count trigger', () => {
  const c = defaults(); c.mode = 4; c.cameraH = 1; c.cameraV = 1;
  const r = evaluate(c, [{id:'observer-1', name:'Observer', x:0,z:.9,eye:1.5}]);
  assert.equal(r.radarCount, 1); assert.equal(r.trigger, false);
});
test('Tilt and yaw change actual coverage', () => {
  const c = defaults(); c.phoneTilt = -30;
  assert.equal(evaluate(c, preset('shoulder')).faceCount, 0);
  c.phoneTilt = 30; c.phoneYaw = 90;
  assert.equal(evaluate(c, preset('shoulder')).faceCount, 0);
});
test('Sector model handles angles over 180 degrees without tangent projection', () => {
  const p = new Vector3(1,0,-.1), o = new Vector3(), q = new Quaternion();
  assert.equal(inCoverage(p,o,q,200,70,2),true); assert.equal(inCoverage(p,o,q,180,70,2),false);
  assert.equal(inCoverage(new Vector3(0,0,3),o,q,200,70,2),false);
});
test('Box ray intersections exclude the target person but include intervening head', () => {
  const people = preset('hidden');
  assert.equal(blockerBetween(new Vector3(0,1.5,0),new Vector3(0,1.5,.8), people, 'observer-1'), 'owner');
  assert.equal(blockerBetween(new Vector3(0,2,0),new Vector3(0,2,.8), people, 'observer-1'), null);
});
