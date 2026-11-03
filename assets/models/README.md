# Local face verification model

## Provenance

- Download verified 2026-11-03, 5,233,552 bytes, TFLite binary.
- Pinned source: https://github.com/MCarlomagno/FaceRecognitionAuth/tree/82372440f26d699e13996014a01805f925dbcdbb
- Download: https://raw.githubusercontent.com/MCarlomagno/FaceRecognitionAuth/82372440f26d699e13996014a01805f925dbcdbb/assets/mobilefacenet.tflite
- SHA-256: `be4bc7cfc53f7bc336d0f28b1ab92535f618c913a422b683210750f6b5354854`
- Git blob: `057b98506a7fe9fb8ac8e64464bcacd6439084eb`.
- Hosting repository license: BSD-3-Clause, Marcos Carlomagno (2020),
  reproduced in LICENSE.mobilefacenet-host.txt. The repository's license is
  verified; separate weight-specific/training-dataset rights are not established
  by that license. This is a prototype artifact, not a claim of cleared dataset
  provenance or biometric certification.
- Upstream preprocessing: pinned `lib/services/ml_service.dart`; RGB float32
  `(channel - 128) / 128`, input `[1,112,112,3]`, output `[1,192]`.
- MobileFaceNet architecture paper: https://arxiv.org/abs/1804.07573

The application checks SHA-256 before loading and checks tensor dimensions.
Changing model or preprocessing requires a new model ID and reenrollment.

## Integration

Owner adds `flutter_litert: ^3.9.3`, `flutter_secure_storage: ^11.2.0` and
`assets/models/mobilefacenet.tflite` to pubspec. Import
`package:privacy_screen_software/face_verification.dart`. Native LiteRT is
conditionally imported; the web backend fails closed without importing Dart FFI.
Android is the implemented target. iOS/BGRA input is currently unsupported.

Create `LocalFaceVerifier()`, await `initialize()`, and handle errors as locked.
Enable ML Kit landmarks. Pass the **same frame**, unmirrored upright ML Kit
`Face`, and the same clockwise rotation degrees (0/90/180/270) to
`await verifier.process(frame, face, rotationDegrees)`. Do not reuse previous
faces with a new frame. Monitor must handle no faces and multiple faces before
calling process. Alternatively `verify(frame, faces, InputImageRotation)` does
face-count handling. Only result `authorized == true` can authorize access;
never cache authorization after a failed frame. Camera shutdown, stream failure,
and stale frames require the enclosing controller to lock. Serialize frame work,
await it before disposal, and discard pending results after camera/session change.
Continue independent tilt and multi-person protection. This verifier does not
change rendered pixels, encryption, PIN handling, or controller state.

After PIN-authenticated enrollment/replacement, call `beginEnrollment()`, feed
frames through `process`, display `enrollmentProgress` and `enrollmentSamples`,
then explicitly await `finishEnrollment()` once at least 8 samples are accepted.
Samples are spaced by at least 400ms and bounded to 20; collect small pose and
lighting variation within the frontal quality gates. `cancelEnrollment()` drops
pending vectors. Existing reference is replaced only after secure storage write
succeeds. `deleteEnrollment()` removes only the face reference. The face store
key `privacy.face_reference.v1` is separate from PIN storage; no images are saved.
Exclude secure-storage preferences from Android backup per the plugin guidance.

## Processing and Threshold Policy

Tightly packed single-plane Android NV21 only; unsupported/padded layouts fail
closed. Rotate coordinates into the source buffer, align two eyes to (38,42) and
(74,42), bilinear sample a 112-square RGB crop, normalize pixels, infer, L2
normalize the embedding. Gates reject clipped/small faces, missing eyes, >20
degree yaw/pitch, excessive roll, low contrast and extreme exposure. These are
prototype quality heuristics, not measured quality or liveness guarantees.

Enrollment computes a unit centroid and leave-one-out cosine distances from
each sample to the centroid of the remaining samples. With mean m, population
standard deviation s, and maximum q, proposed distance threshold is
`max(q + 0.02, m + 3*s + 0.02)`. Reject enrollment if it exceeds 0.20;
otherwise use `max(0.04, proposed)`. Larger distance is rejected. This gives
enrollment-dependent variation tolerance with an **unvalidated conservative
maximum distance of 0.20** (minimum cosine similarity 0.80). The 0.02 margin,
0.04 floor and 0.20 cap are explicit prototype policy choices, not estimates of
FAR, FRR, TAR, EER or statistically calibrated security. Enrollment consistency
cannot establish impostor separation. Poor enrollment must be repeated rather
than raising the cap. No adaptive online template updates are performed.

Before security claims, collect independent genuine and consenting impostor
sessions across device, lighting, glasses and pose, keeping enrollment separate.
Report genuine/impostor distributions, ROC/FAR/FRR with sample counts and
confidence limits; select a threshold on validation data and evaluate held-out
sessions. Measure preprocessing/inference latency on the target Android phone.
No measured calibration, accuracy or runtime latency is claimed here.

For a reproducible device benchmark, use a release/profile Android build, record
phone model, Android version, CPU ABI, camera resolution, model hash and thermal
state. Time `process` with a Stopwatch around the awaited call, separately time
ML Kit detection in the monitor, warm up 20 single-face frames, then record at
least 200 accepted-quality frames and report p50/p95/max milliseconds, dropped
frame count and quality rejection rate. Repeat with enrollment disabled and with
8-sample enrollment. Include initialization separately. Do not report debug-mode
latency as deployment performance. No raw face frames need be retained.

This embedding verifier has no presentation-attack/liveness detection; a photo
or replay may pass. It is not Android BiometricPrompt or a replacement for a
hardware-backed biometric authenticator. Device frame/landmark alignment and
enrollment/verification must still be exercised on the actual phone.
