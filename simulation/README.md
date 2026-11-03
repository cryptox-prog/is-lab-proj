# Illustrative privacy geometry simulator

A separate **[block-level 3D version](three-d/README.md)** is now available with
head/torso ray occlusion, eye heights, phone tilt, and independent screen sightlines.

Independent of the Flutter app. All defaults are scenario assumptions, **not measured calibration**.

From the repository root:

```sh
python -m venv simulation/.venv
simulation/.venv/bin/pip install -r simulation/requirements.txt
simulation/.venv/bin/python -m simulation.simulator --config simulation/scenario.json
simulation/.venv/bin/python -m unittest discover -s simulation/tests -v
MPLCONFIGDIR=/tmp/privacy-mpl simulation/.venv/bin/python -m analysis.generate
simulation/.venv/bin/python -m analysis.check_outputs
```

Interactive matplotlib uses a GUI backend or falls back to WebAgg in headless environments.
To explicitly use a local browser: add `--backend WebAgg` and open the printed localhost URL.
WebAgg's small local server needs tornado, included in requirements. Stop it with Ctrl-C.
Click to add an observer, drag a circle to move it, right click to delete. Radio buttons select
the six modes. The **Body occlusion (2D)** checkbox enables an optional opaque-circle
scenario. It is off by default: visible faces inside the camera cone, including behind
the designated user, are detected. A top-down position alone cannot establish that
a face is blocked; the model has no head-height or over-the-shoulder visibility data.
Edit the JSON to set any `Config` field: distance, phone orientation, optical
angles, radar position/orientation, range, radius, and optical/radar occlusion switches.
Restart to apply JSON changes. Phone heading rotates the designated user's reference position;
existing observers and radar remain in world coordinates.

For headless rendering:

```sh
MPLBACKEND=Agg MPLCONFIGDIR=/tmp/privacy-mpl simulation/.venv/bin/python -m simulation.simulator --mode 5 --output simulation/screenshot.png
```

Modes are zero-indexed at the CLI: app, app+privacy, app+fisheye,
app+fisheye+privacy, app+radar, app+radar+privacy. Exported figures use 1--6.

## Geometry and status contract

- Coordinates are meters: phone at `(0,0)`, heading zero points along `+y`, positive heading
  rotates toward `+x`. All FOVs are **total** degrees, boundaries included. Radar pose is independent.
- Camera 75 degrees is an illustrative midpoint of 70--80. Privacy readability is 60 degrees.
  Bare-screen readability is an explicitly assumed 160 degrees, not empirical.
  Fisheye nominal optical angle is 180 degrees, effective detection is an explicitly assumed
  120 degrees. Manufacturer projection and measured effective FOV are unknown.
- Distances 0.35, 0.40, 0.55, 0.60 m are reference scenarios, not measurements. Range 2 m,
  body radius 0.10 m, and radar pose `(-0.6,-0.2)` m are illustrative too.
- The model uses sectors, including angles >=180 degrees. No fisheye image projection is
  assumed. Width is the intersection of a sector with a forward plane, calculated only below
  180 degrees. It is not a fisheye image width or calibrated detection performance.
- Radar 120 horizontal / 70 vertical degrees are reference parameters. Vertical geometry,
  elevation, phone pitch/roll, tracking limits, stationary targets, and detection probabilities
  are not simulated. Phone orientation here is horizontal yaw only.
- Optional optical occlusion uses body circles: a blocker center must project strictly inside
  the sensor-to-person segment, with perpendicular distance <= radius. The target itself is
  excluded; an owner at the target endpoint does not block that target. This is an approximate
  centerline model, not anatomical visibility. Readability ignores body obstruction conservatively.
- Radar occlusion uses the same optional circle/segment approximation. Default off means an
  optimistic geometric visibility scenario, **not a claim that radar penetrates all bodies**.
  Set `radar_occlusion: true` to compare the opaque-body scenario. Neither is a propagation model.
- `evaluate(config, mode, observers)` returns `(observer_rows, protection_trigger, radar_count)`.
  Each row contains `readable`, `optical`, `radar`, `detected`,
  `readable_but_undetected`, and `breach`. Optical denotes the active normal/fisheye sensor.
  Radar flags are false when radar is disabled. The designated user is not an optical threat.
- Radar counts everyone in its sector; **more than one** target triggers protection without
  identity inference. A single observer visible to radar with the user outside radar can be
  detected without triggering protection. Tests cover this residual failure.
- RBU is readable AND outside active sensor visibility. `breach` is readable AND no global
  protection trigger. These differ under the radar count rule. SAFE/BREACH is independent of
  trigger status. Triggered content is assumed immediately hidden; no actual rendering latency,
  encryption, authentication, or persistent protection latch is simulated. A prior latched lock
  could keep content hidden beyond the instantaneous geometry represented here.
- Green circles are outside readability and detection, orange detected, red RBU or current breach. Red background
  samples a **single hypothetical observer plus owner**, independent of placed observers.
  SAFE means no modeled current breach, not a real-world security guarantee.
- In the same-origin unobstructed case, a 75-degree camera contains the entire 60-degree
  readable sector: zero angular blind region. Body occlusion still creates an RBU region.

No application or paper sources are modified. Generated artifacts belong to `analysis/generated/`.
