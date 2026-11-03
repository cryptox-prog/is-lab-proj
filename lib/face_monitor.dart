import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'desktop_face_monitor.dart';
import 'face_verification.dart';
import 'web_face_monitor_stub.dart'
    if (dart.library.js_interop) 'web_face_monitor.dart'
    as browser;

abstract interface class FaceMonitor {
  Stream<int> get counts;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class IdentityFaceMonitor {
  Stream<FaceVerificationResult> get identities;
  bool get verificationSupported;
  bool get faceEnrolled;
  int get identityEpoch;
  Future<void> beginFaceEnrollment();
  Future<void> finishFaceEnrollment();
  void cancelFaceEnrollment();
}

FaceMonitor createFaceMonitor() {
  if (kIsWeb) return browser.createWebFaceMonitor();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return CameraFaceMonitor();
  }
  return DesktopFaceMonitor();
}

class CameraFaceMonitor implements FaceMonitor, IdentityFaceMonitor {
  final _counts = StreamController<int>.broadcast();
  final _identities = StreamController<FaceVerificationResult>.broadcast();
  final _verifier = LocalFaceVerifier();
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.08,
      enableLandmarks: true,
      enableTracking: true,
    ),
  );
  CameraController? _camera;
  Future<void>? _processing;
  final _clock = Stopwatch()..start();
  int _lastFrame = -200;
  bool _disposed = false;
  int? _trackingId;
  int? _previousCount;
  int _identityEpoch = 0;
  String? _verificationError;

  @override
  Stream<FaceVerificationResult> get identities => _identities.stream;
  @override
  bool get verificationSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  bool get faceEnrolled => _verifier.isEnrolled;
  @override
  int get identityEpoch => _identityEpoch;
  @override
  Future<void> beginFaceEnrollment() async {
    if (!verificationSupported) {
      throw UnsupportedError('Android enrollment only');
    }
    await _verifier.initialize();
    _verifier.beginEnrollment();
    _identities.add(
      const FaceVerificationResult(FaceVerificationStatus.enrolling),
    );
  }

  @override
  Future<void> finishFaceEnrollment() async {
    await _verifier.finishEnrollment();
    _identities.add(
      const FaceVerificationResult(
        FaceVerificationStatus.uncertain,
        reason: 'Face saved. Verify to restore access.',
      ),
    );
  }

  @override
  void cancelFaceEnrollment() => _verifier.cancelEnrollment();

  @override
  Stream<int> get counts => _counts.stream;

  @override
  Future<void> start() async {
    if (_disposed || _camera != null) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw StateError('Face protection requires an Android or iOS phone.');
    }
    final cameras = await availableCameras();
    final front = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    if (front.isEmpty) throw StateError('No front camera is available.');
    final camera = CameraController(
      front.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _camera = camera;
    try {
      await camera.initialize();
      if (verificationSupported) {
        try {
          await _verifier.initialize();
          _verificationError = null;
        } catch (_) {
          _verificationError = 'Face verification unavailable. Use PIN.';
        }
      }
      await camera.startImageStream((frame) {
        if (_disposed ||
            _processing != null ||
            _camera != camera ||
            _clock.elapsedMilliseconds - _lastFrame < 200) {
          return;
        }
        _lastFrame = _clock.elapsedMilliseconds;
        _processing = _detect(
          frame,
          camera,
        ).whenComplete(() => _processing = null);
      });
    } catch (_) {
      _camera = null;
      await camera.dispose();
      rethrow;
    }
  }

  Future<void> _detect(CameraImage frame, CameraController camera) async {
    try {
      final format = InputImageFormatValue.fromRawValue(frame.format.raw);
      final android = defaultTargetPlatform == TargetPlatform.android;
      if (frame.planes.length != 1 ||
          format !=
              (android ? InputImageFormat.nv21 : InputImageFormat.bgra8888)) {
        throw StateError('Unsupported camera frame format.');
      }
      const orientations = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };
      final degrees = android
          ? (camera.description.sensorOrientation +
                    orientations[camera.value.deviceOrientation]!) %
                360
          : camera.description.sensorOrientation;
      final rotation = InputImageRotationValue.fromRawValue(degrees);
      if (rotation == null) throw StateError('Unsupported camera rotation.');
      final plane = frame.planes.first;
      final input = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format!,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
      final faces = await _detector
          .processImage(input)
          .timeout(const Duration(seconds: 3));
      if (_disposed || _camera != camera) return;
      final trackingId = faces.length == 1 ? faces.single.trackingId : null;
      if (_previousCount != faces.length ||
          (trackingId != null && trackingId != _trackingId)) {
        _identityEpoch++;
      }
      _previousCount = faces.length;
      _trackingId = trackingId;
      _counts.add(faces.length);
      if (!verificationSupported) return;
      final result = _verificationError == null
          ? await _verifier.verify(frame, faces, rotation)
          : FaceVerificationResult(
              FaceVerificationStatus.uncertain,
              reason: _verificationError,
            );
      if (!_disposed && _camera == camera) _identities.add(result);
    } catch (error) {
      if (!_disposed && _camera == camera) _counts.addError(error);
    }
  }

  @override
  Future<void> stop() async {
    final camera = _camera;
    _camera = null;
    _trackingId = null;
    _previousCount = null;
    _identityEpoch++;
    _verifier.cancelEnrollment();
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } finally {
      await _processing;
      await camera.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _detector.close();
    await _verifier.dispose();
    await _counts.close();
    await _identities.close();
  }
}
