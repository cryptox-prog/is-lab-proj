# PrivaSc block-level 3D simulator

Separate local Three.js application. No camera access, biometric images, backend,
or Flutter changes. Use Node 22.12+ (tested with Node 26).

```sh
cd simulation/three-d
npm ci
npm run dev
```

Open the printed local URL (normally http://127.0.0.1:8090). `npm test` runs and
prints all 14 geometry checks individually.
`npm run build` produces a standalone static bundle in `dist/` for HTTP hosting.

## Scene controls

Orbit/zoom with the mouse or touch. Drag a person's blocks to move them on the
floor, or select them and edit lateral position, distance, and eye height. The
owner cannot be deleted. Add/remove observers, select six sensor/filter modes,
or load visible-over-shoulder, hidden, lateral, and owner-only presets. Toolbar
buttons select perspective/top/phone views, reset the scene, or download a PNG.
Phone position/tilt/yaw, optical angles/range and radar placement are adjustable.

## Model and evidence boundary

- World coordinates are meters: Y is height, Z is distance in front of the phone,
  X is lateral. All angles are total degrees. The phone front points along +Z
  before its yaw/tilt rotation. Eye height is not total person height.
- Default reference angles match the 2D scenarios: normal camera 75 H, filter
  readable 60 H, assumed effective fisheye 120 H, radar 120 H / 70 V. Added
  camera 60 V, fisheye 90 V, readable 160 V, 2 m range, phone height 1.2 m and
  30-degree tilt, body dimensions and person heights are **unmeasured assumptions**.
  These are not imported or claimed physical calibration results.
- Heads, torsos and legs are rotated cuboids. Three.js ray/box intersection tests
  transform sightlines into the same local coordinates as the rendered bodies.
  A face is sampled at nine points; five visible in-sector samples mean optical
  visibility. That majority rule is a geometry heuristic, not face detector accuracy.
  People are assumed to face the phone; head pose, image resolution and ML inference
  are not simulated. Overlapping bodies are allowed as a modelling limitation.
- Camera visibility and screen readability are separate. The camera has a slightly
  different location from the display. By default an observer must have an
  unobstructed eye-to-display path to at least one of nine display samples and be
  in the readable angle/range. This is approximate potential readability, not
  readable font/contrast testing. The Screen line of sight switch permits a
  conservative angle-only comparison. The body occlusion switch affects the
  camera independently, so disabling it does not disable screen blockage.
- A centered person behind an aligned head can be blocked, but a higher/lateral
  face can be visible. A blocked camera path is not automatically an exposure:
  the same body may also prevent screen reading. CLEAR means no current modeled
  exposure; it does not mean the app has authenticated an unseen person.
- Radar counts body centers in its independent ideal angular sector, with no
  identity, multipath, merging, stationary-target loss or body attenuation model.
  **Count > 1** triggers. One radar-visible observer without the owner does not.
  Neither a sector nor an ideal radar result guarantees real-world detection.
- An optically visible designated non-owner also triggers protection, representing
  the app's multi-face/unauthorized-face policy with oracle identity. This does not
  execute the actual embedding model. The simulator uses instantaneous protection,
  not the Flutter PIN/face reauthorization latch or sensor timeout logic.
- EXPOSED means a readable observer and no global trigger; PROTECTED means a
  trigger, including nuisance triggers from observers who cannot read the screen.
  RBU (readable outside sensing) is distinct from count-policy exposure.
- Coverage meshes are angular spherical envelopes, including >180 H scenarios;
  no tangent-based fisheye projection is used. The phone view is an orbitable
  perspective inspection view, **not an optically accurate fisheye image** and
  its viewport aspect can differ from the assumed sensor angles.
- No real motion thresholds are simulated: phone orientation rotates sensing and
  screen geometry rather than triggering the production orientation controller.

The existing Python/2D simulator, analysis tables and paper remain available and
unchanged by this 3D extension.
