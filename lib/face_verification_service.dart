import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_verification_backend.dart';
import 'face_verification_math.dart';
import 'face_verification_store.dart';

enum FaceVerificationStatus {
  noFace,
  multipleFaces,
  authorized,
  unauthorized,
  uncertain,
  enrolling,
}

class FaceVerificationResult {
  final FaceVerificationStatus status;
  final int enrollmentSamples;
  final double? cosineDistance;
  final String? reason;
  const FaceVerificationResult(
    this.status, {
    this.enrollmentSamples = 0,
    this.cosineDistance,
    this.reason,
  });
  double get enrollmentProgress => (enrollmentSamples / 8).clamp(0.0, 1.0);
  bool get authorized => status == FaceVerificationStatus.authorized;
}

class LocalFaceVerifier {
  static const modelId = 'mobilefacenet-be4bc7cf-eyealign-v1';
  final FaceReferenceStore store;
  final _backend = FaceEmbeddingBackend();
  final _samples = <List<double>>[];
  final _clock = Stopwatch()..start();
  FaceEnrollmentProfile? _profile;
  bool _ready = false;
  bool _disposed = false;
  bool _enrolling = false;
  bool _busy = false;
  int _lastSample = -1000;
  LocalFaceVerifier({this.store = const FaceReferenceStore()});
  bool get isEnrolled => _profile != null;
  bool get isEnrolling => _enrolling;
  int get enrollmentSamples => _samples.length;

  Future<void> initialize() async {
    if (_disposed) throw StateError('Verifier disposed');
    if (_ready) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Local face verification currently supports Android',
      );
    }
    await _backend.initialize();
    _profile = await store.load(modelId);
    _ready = true;
  }

  /// Caller must authenticate enrollment/replacement with the PIN first.
  void beginEnrollment() {
    if (!_ready || _disposed || _busy) throw StateError('Verifier unavailable');
    _samples.clear();
    _lastSample = -1000;
    _enrolling = true;
  }

  void cancelEnrollment() {
    _samples.clear();
    _enrolling = false;
  }

  Future<void> finishEnrollment() async {
    if (!_enrolling || _busy || _disposed) throw StateError('Not enrolling');
    _busy = true;
    try {
      final profile = FaceEnrollmentProfile.fromSamples(_samples);
      await store.save(modelId, profile);
      if (_disposed) return;
      _profile = profile;
      cancelEnrollment();
    } finally {
      _busy = false;
    }
  }

  Future<void> deleteEnrollment() async {
    _profile = null;
    cancelEnrollment();
    await store.delete();
  }

  Future<FaceVerificationResult> verify(
    CameraImage frame,
    List<Face> faces,
    InputImageRotation rotation,
  ) async {
    if (faces.length != 1) {
      return FaceVerificationResult(
        faces.isEmpty
            ? FaceVerificationStatus.noFace
            : FaceVerificationStatus.multipleFaces,
      );
    }
    return process(frame, faces.single, rotation.rawValue);
  }

  Future<FaceVerificationResult> addEnrollmentSample(
    CameraImage frame,
    Face face,
    int rotationDegrees,
  ) => process(frame, face, rotationDegrees);

  /// Face coordinates must be ML Kit's upright, unmirrored coordinates from
  /// this exact frame. The monitor must reject zero/multiple faces first.
  Future<FaceVerificationResult> process(
    CameraImage frame,
    Face face,
    int rotationDegrees,
  ) async {
    if (!_ready || _disposed || _busy) {
      return const FaceVerificationResult(
        FaceVerificationStatus.uncertain,
        reason: 'Verifier unavailable',
      );
    }
    _busy = true;
    try {
      final input = alignedFaceRgb(frame, face, rotationDegrees);
      final embedding = normalizeFaceEmbedding(_backend.embed(input));
      if (_enrolling) {
        if (_clock.elapsedMilliseconds - _lastSample >= 400 &&
            _samples.length < 20) {
          if (_samples.isNotEmpty &&
              faceCosineDistance(_samples.first, embedding) > 0.20) {
            return const FaceVerificationResult(
              FaceVerificationStatus.uncertain,
              reason: 'Inconsistent enrollment face',
            );
          }
          _samples.add(embedding);
          _lastSample = _clock.elapsedMilliseconds;
        }
        return FaceVerificationResult(
          FaceVerificationStatus.enrolling,
          enrollmentSamples: _samples.length,
        );
      }
      final profile = _profile;
      if (profile == null) {
        return const FaceVerificationResult(
          FaceVerificationStatus.uncertain,
          reason: 'Enrollment required',
        );
      }
      final distance = faceCosineDistance(embedding, profile.reference);
      return FaceVerificationResult(
        distance <= profile.threshold
            ? FaceVerificationStatus.authorized
            : FaceVerificationStatus.unauthorized,
        cosineDistance: distance,
      );
    } catch (_) {
      return const FaceVerificationResult(
        FaceVerificationStatus.uncertain,
        reason: 'Frame quality or inference failure',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _ready = false;
    _profile = null;
    cancelEnrollment();
    _backend.dispose();
  }
}

/// Two-eye similarity alignment to canonical (38,42), (74,42) on 112 RGB.
/// Supports tightly packed NV21 only. Other layouts fail closed.
Float32List alignedFaceRgb(CameraImage frame, Face face, int rotation) {
  if (![0, 90, 180, 270].contains(rotation) ||
      frame.format.group != ImageFormatGroup.nv21 ||
      frame.planes.length != 1 ||
      frame.width.isOdd ||
      frame.height.isOdd ||
      frame.planes.single.bytesPerRow != frame.width) {
    throw const FormatException('Unsupported NV21 layout');
  }
  final bytes = frame.planes.single.bytes;
  final w = frame.width, h = frame.height;
  if (bytes.length < w * h * 3 ~/ 2) throw const FormatException('Short NV21');
  final uw = rotation % 180 == 0 ? w : h;
  final uh = rotation % 180 == 0 ? h : w;
  final box = face.boundingBox;
  if (box.width < 80 ||
      box.height < 80 ||
      box.left < 0 ||
      box.top < 0 ||
      box.right > uw ||
      box.bottom > uh ||
      face.headEulerAngleY == null ||
      face.headEulerAngleX == null ||
      face.headEulerAngleY!.abs() > 20 ||
      face.headEulerAngleX!.abs() > 20) {
    throw const FormatException('Face size, clipping or pose');
  }
  final a = face.landmarks[FaceLandmarkType.leftEye]?.position;
  final b = face.landmarks[FaceLandmarkType.rightEye]?.position;
  if (a == null || b == null) throw const FormatException('Eyes required');
  final left = a.x < b.x ? a : b;
  final right = a.x < b.x ? b : a;
  final dx = (right.x - left.x).toDouble();
  final dy = (right.y - left.y).toDouble();
  if (math.sqrt(dx * dx + dy * dy) < 24 || dy.abs() > dx * 0.5) {
    throw const FormatException('Eye geometry');
  }
  for (final eye in [left, right]) {
    if (eye.x < box.left ||
        eye.x > box.right ||
        eye.y < box.top ||
        eye.y > box.bottom) {
      throw const FormatException('Eye outside face');
    }
  }
  List<double> pixel(int x, int y) {
    final yy = bytes[y * w + x].toDouble();
    final uv = w * h + (y ~/ 2) * w + (x ~/ 2) * 2;
    final v = bytes[uv] - 128, u = bytes[uv + 1] - 128;
    final c = math.max(0, yy - 16) * 1.164;
    return [
      (c + 1.596 * v).clamp(0, 255).toDouble(),
      (c - 0.392 * u - 0.813 * v).clamp(0, 255).toDouble(),
      (c + 2.017 * u).clamp(0, 255).toDouble(),
    ];
  }

  final output = Float32List(112 * 112 * 3);
  var sum = 0.0, sum2 = 0.0;
  for (var y = 0; y < 112; y++) {
    for (var x = 0; x < 112; x++) {
      final ox = (x - 38) / 36, oy = (y - 42) / 36;
      final ux = left.x + dx * ox - dy * oy;
      final uy = left.y + dy * ox + dx * oy;
      final (sx, sy) = switch (rotation) {
        90 => (uy, h - 1 - ux),
        180 => (w - 1 - ux, h - 1 - uy),
        270 => (w - 1 - uy, ux),
        _ => (ux, uy),
      };
      if (sx < 0 || sy < 0 || sx >= w - 1 || sy >= h - 1) {
        throw const FormatException('Aligned crop outside image');
      }
      final ix = sx.floor(), iy = sy.floor();
      final fx = sx - ix, fy = sy - iy;
      final p00 = pixel(ix, iy), p10 = pixel(ix + 1, iy);
      final p01 = pixel(ix, iy + 1), p11 = pixel(ix + 1, iy + 1);
      for (var c = 0; c < 3; c++) {
        final value =
            p00[c] * (1 - fx) * (1 - fy) +
            p10[c] * fx * (1 - fy) +
            p01[c] * (1 - fx) * fy +
            p11[c] * fx * fy;
        output[(y * 112 + x) * 3 + c] = (value - 128) / 128;
        sum += value;
        sum2 += value * value;
      }
    }
  }
  final mean = sum / output.length;
  if (mean < 35 || mean > 220 || sum2 / output.length - mean * mean < 100) {
    throw const FormatException('Exposure or contrast');
  }
  return output;
}
