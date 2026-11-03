# Validation record: 2026-11-03

## Block-level 3D extension

`simulation/three-d/` is separate from the Flutter app and the original Python
simulator. Fourteen Node geometry tests pass: visible over-shoulder faces, true
head blockage, separate screen blockage, elevated faces, all six modes, radar
count policy, orientation, range and Three.js ray/box intersections. Production
build passes; npm audit reports zero vulnerabilities for its dependency lock.
The build emits a non-fatal 525 kB chunk-size advisory.

Playwright/Chrome verified orbit motion, direct block dragging, add/remove and
height controls, scene presets, radar/mode switching, and phone-camera inspection.
Desktop and mobile screenshots were inspected. WebGL readback found 368 sampled
colors on the 1128 x 862 desktop canvas; mobile readback also passed the nonblank
check. No mobile horizontal overflow or browser page errors occurred. These tests
exercise synthetic geometry, not actual camera images or measured detector accuracy.

## Checks performed

| Check | Outcome |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | 30 tests passed |
| `flutter build apk --debug --target-platform android-arm64` | APK built |
| APK contents | Pinned MobileFaceNet asset and ARM64 LiteRT libraries present |
| `flutter build web --no-wasm-dry-run` | Web build passed |
| Chrome browser with deterministic blank fake webcam | Camera counts, PIN setup, wrong-PIN rejection, stable correct-PIN unlock, persisted PIN, protected reload passed |
| Desktop and mobile browser layout | Inspected rendered screenshots |
| Geometry unit tests | 11 passed, including visible central faces, all six modes, optional occlusion, boundaries and radar count/identity distinction |
| `python -m analysis.check_outputs` | Numerical CSV/LaTeX tables, scenario, classifications and 26 figure files consistent |
| Interactive simulator in Chrome/WebAgg | Nonblank 899 x 700 canvas; 58,335 nonwhite pixels; screenshot inspected |
| IEEE paper compilation | 8-page PDF generated; no missing citations/references, overfull boxes or oversized floats |
| `git diff --check` | Passed |

The default animated Chrome fake-camera test pattern intermittently produced a
single detected face. This correctly revoked a PIN-authorized zero-face session
on count change. Stable-render checks used a plain gray Y4M fixture instead. This
observation is not a real-camera accuracy result. Browser screenshots are test
captures; the paper's three phone screenshot placeholders remain intentional.

## Evidence limits

- Only Linux and Chrome were connected; no Android phone was available. APK build
  success does not prove enrollment or inference works on a physical phone.
- Camera/controller/widget tests inject counts, identities and orientation.
  The five embedding tests exercise math, quality handling and NV21 rotations,
  not a real person's inference accuracy. No FAR/FRR or inference latency is claimed.
- No new Windows, macOS, iOS or Linux desktop build/device check was performed
  for this authentication extension. Secure storage remains platform dependent.
- Fisheye/radar hardware is not integrated into the phone app. Simulator outputs
  are deterministic geometry, not radar propagation or computer-vision tests.
- Supplied FOV/distance ranges are reference inputs, not physical calibration.
  Trial logs are intentionally unfilled. The effective fisheye angle of 120
  degrees and other scenario defaults are explicitly assumptions.
- Model weight-specific licensing/training provenance is not established beyond
  the hosting repository license. Face verification has no liveness protection.
- Paper author details and three physical-device screenshots remain placeholders.
  Two supplied references are preserved as unverified metadata rather than cited
  as evidence. The final LaTeX log has one benign underfull page-box notice, not
  overflowing content.
