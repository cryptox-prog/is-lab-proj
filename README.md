# PrivaSc

Flutter privacy-screen prototype, a separate geometry simulator, and an IEEE
conference-format research draft. This is not a certified biometric authenticator.

## Camera Protection

Camera protection runs on Android, iOS, Windows, macOS, Linux, and web.
Two or more detected faces encrypt the displayed text and images immediately.
Three consecutive detections with at most one face clear the camera-count threat,
but **do not automatically reveal protected content**. A lock is latched until
reauthorization by an enrolled face or the PIN. On native mobile, calibrated
motion thresholds must also be satisfied. Camera errors/stale frames block PIN
unlock, as do unsafe orientation and multiple faces.
Web and desktop use camera protection without requiring a gyroscope.
Camera errors or stale detections keep the content protected.

Camera frames are processed on-device and are not saved or uploaded.
Android and iOS use ML Kit; web and desktop use MediaPipe models through LiteRT.
Browser camera access requires HTTPS or localhost and camera permission.
The browser LiteRT runtime loads from its pinned CDN on first use.

Run web with `flutter run -d chrome`, or desktop with `flutter run -d linux`,
`flutter run -d windows`, or `flutter run -d macos` on the matching host.
Linux builds require GStreamer development libraries and camera plugins
(`gstreamer-1.0`, `gstreamer-app-1.0`, and the good plugins).
macOS camera usage permission and sandbox entitlements are configured in `macos/Runner`.

## Authentication

- Set up a matching PIN of at least six digits using the protected-screen button.
  PIN setup does not unlock the article; use the PIN after camera/sensor checks
  clear. Credentials use PBKDF2-HMAC-SHA256 (210,000 iterations, random 32-byte
  salt) in platform secure storage. Three incorrect attempts enforce a persisted
  30-second cooldown. No default PIN is shipped.
- Android: open Settings, choose **Enroll face**, confirm the PIN, collect at
  least eight accepted frontal samples, then choose **Save face**. Content stays
  covered during enrollment. Replacing enrollment also requires the PIN.
- Android verification uses a pinned MobileFaceNet model with eye alignment and
  normalized cosine distance. Three consecutive accepted matches can authorize
  access when physical signals are safe. Unauthorized/uncertain results lock
  content unless a PIN has explicitly authorized the current continuous tracked
  session. Face count/tracking changes, backgrounding, and physical threats revoke
  that PIN session. Tracking is not a guaranteed identity boundary.
- iOS, web, and desktop currently use PIN authorization plus existing camera-count
  protection; embedding enrollment/verification is Android-only.
- Face references contain embeddings, not saved images, and use secure storage.
  Threshold adaptation measures enrollment consistency only: genuine/impostor
  calibration and physical-device validation remain outstanding. No liveness or
  photo/replay defense is implemented. Model provenance/license caveats and the
  validation procedure are in [assets/models/README.md](assets/models/README.md).
- Reset/recovery UI is deliberately not provided. Losing the PIN may require
  clearing app data; do not use this prototype for irreplaceable content.

When locked, the UI removes sensitive widgets from painting, input, and semantics
behind an opaque cover, independently of the AES operation. Rendering changes
take effect on the next Flutter paint, not at zero physical latency. The
AES-256-GCM vault is session-only; original bundled blog text/images are plaintext
assets, and keys live in process memory. This is a display-protection prototype,
not encrypted file storage or whole-phone screen protection.

## Research Deliverables

- [3D simulator](simulation/three-d/README.md): browser-based block scene with
  movable people, eye heights, phone orientation and ray-tested visibility.

- [paper/main.tex](paper/main.tex): IEEE conference source and bibliography.
- [paper/main.pdf](paper/main.pdf): compiled draft, with three app screenshot slots.
- [simulation/README.md](simulation/README.md): independent Python/matplotlib
  six-mode simulator with observer placement and configurable geometry.
- [analysis/README.md](analysis/README.md): generated figures, CSV/LaTeX tables,
  and reproducibility checks.
- [analysis/calibration/README.md](analysis/calibration/README.md): physical
  calibration protocol and blank trial log. Supplied angle ranges/distances are
  reference/scenario inputs, not physical measurements.

The fisheye and radar configurations are geometric analyses, not connected
hardware drivers in the Flutter app. Radar uses **more than one target -> threat**
and makes no identity claim. The paper explicitly distinguishes nominal lens FOV,
assumed effective detection FOV, and missing measured calibration.

## Validation

```sh
flutter analyze
flutter test
flutter build apk --debug
simulation/.venv/bin/python -m unittest discover -s simulation/tests -v
MPLCONFIGDIR=/tmp/privacy-mpl simulation/.venv/bin/python -m analysis.check_outputs
```

Install simulator dependencies as described in its README. Automated camera and
orientation tests use injected signals; they do not validate real-camera accuracy.
No Android device was connected during this change. Genuine/impostor evaluation,
physical camera/gyro checks, enrollment latency, and radar/fisheye calibration
must be performed before claiming real-world security or detection coverage.
