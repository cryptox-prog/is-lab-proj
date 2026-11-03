import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:privacy_screen_software/face_verification_math.dart';
import 'package:privacy_screen_software/face_verification_store.dart';
import 'package:privacy_screen_software/face_verification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('NV21 eye alignment is consistent across all rotations', () {
    final face = Face(
      boundingBox: const Rect.fromLTWH(40, 40, 160, 170),
      headEulerAngleX: 0,
      headEulerAngleY: 0,
      contours: {},
      landmarks: {
        FaceLandmarkType.leftEye: FaceLandmark(
          type: FaceLandmarkType.leftEye,
          position: const Point(90, 100),
        ),
        FaceLandmarkType.rightEye: FaceLandmark(
          type: FaceLandmarkType.rightEye,
          position: const Point(150, 100),
        ),
      },
    );
    List<double>? expected;
    for (final rotation in [0, 90, 180, 270]) {
      final bytes = Uint8List(256 * 256 * 3 ~/ 2)
        ..fillRange(0, 256 * 256 * 3 ~/ 2, 128);
      for (var y = 0; y < 256; y++) {
        for (var x = 0; x < 256; x++) {
          final (ux, uy) = switch (rotation) {
            90 => (255 - y, x),
            180 => (255 - x, 255 - y),
            270 => (y, 255 - x),
            _ => (x, y),
          };
          bytes[y * 256 + x] = 50 + ux ~/ 2 + uy ~/ 8;
        }
      }
      // Fixture uses the legacy map constructor to avoid a new direct package.
      // ignore: deprecated_member_use
      final frame = CameraImage.fromPlatformData({
        'width': 256,
        'height': 256,
        'format': 17,
        'planes': [
          {
            'bytes': bytes,
            'bytesPerRow': 256,
            'bytesPerPixel': 1,
            'width': 256,
            'height': 256,
          },
        ],
      });
      final actual = alignedFaceRgb(frame, face, rotation);
      expect(actual.length, 112 * 112 * 3);
      if (expected != null) {
        for (var i = 0; i < actual.length; i++) {
          expect(actual[i], closeTo(expected[i], 1e-6));
        }
      }
      expected = actual;
      expect(() => alignedFaceRgb(frame, face, 45), throwsFormatException);
    }
  });
  test('normalization and cosine are scale invariant', () {
    expect(normalizeFaceEmbedding([3, 4]), [0.6, 0.8]);
    expect(faceCosineDistance([3, 4], [6, 8]), closeTo(0, 1e-12));
    expect(faceCosineDistance([1, 0], [0, 1]), 1);
    expect(() => normalizeFaceEmbedding([0, 0]), throwsFormatException);
    expect(() => normalizeFaceEmbedding([double.nan]), throwsFormatException);
  });
  test('enrollment rejects insufficient or mixed identity samples', () {
    expect(
      () => FaceEnrollmentProfile.fromSamples([
        [1, 0],
      ]),
      throwsFormatException,
    );
    expect(
      () => FaceEnrollmentProfile.fromSamples(
        List.generate(8, (i) => i.isEven ? [1.0, 0.0] : [0.0, 1.0]),
      ),
      throwsFormatException,
    );
  });
  test('threshold adapts to dispersion but stays within policy cap', () {
    final tight = FaceEnrollmentProfile.fromSamples(
      List.generate(8, (_) => [1.0, 0.0]),
    );
    final varied = FaceEnrollmentProfile.fromSamples(
      List.generate(8, (i) => [1.0, i.isEven ? 0.25 : -0.25]),
    );
    expect(tight.threshold, 0.04);
    expect(varied.threshold, greaterThan(tight.threshold));
    expect(varied.threshold, lessThanOrEqualTo(0.20));
    expect(
      faceCosineDistance([0, 1], varied.reference),
      greaterThan(varied.threshold),
    );
  });
  test(
    'secure reference round trips and rejects wrong model and corruption',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = FaceReferenceStore();
      expect(await store.load('model'), isNull);
      final vector = List<double>.filled(192, 0)..[0] = 1;
      await store.save('model', FaceEnrollmentProfile(vector, 0.08));
      expect((await store.load('model'))!.reference, vector);
      await expectLater(store.load('other'), throwsFormatException);
      await const FlutterSecureStorage().write(
        key: 'privacy.face_reference.v1',
        value: jsonEncode({
          'version': 1,
          'model': 'model',
          'reference': vector,
          'threshold': 0.9,
        }),
      );
      await expectLater(store.load('model'), throwsFormatException);
      await store.delete();
      expect(await store.load('model'), isNull);
    },
  );
}
