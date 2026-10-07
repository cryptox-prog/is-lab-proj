# Software Privacy Screen

- Encrypt with AES when spoofing is possible 

## Camera Protection

Camera protection runs on Android, iOS, Windows, macOS, Linux, and web.
Two or more detected faces encrypt the displayed text and images immediately.
Three consecutive detections with at most one face allow automatic restoration.
On native mobile, the calibrated motion thresholds must also be satisfied.
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
