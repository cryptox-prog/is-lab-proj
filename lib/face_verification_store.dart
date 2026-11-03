import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'face_verification_math.dart';

class FaceReferenceStore {
  static const _key = 'privacy.face_reference.v1';
  final FlutterSecureStorage storage;
  const FaceReferenceStore({this.storage = const FlutterSecureStorage()});

  Future<void> save(String modelId, FaceEnrollmentProfile profile) =>
      storage.write(
        key: _key,
        value: jsonEncode({
          'version': 1,
          'model': modelId,
          'reference': profile.reference,
          'threshold': profile.threshold,
        }),
      );

  Future<FaceEnrollmentProfile?> load(String modelId) async {
    final raw = await storage.read(key: _key);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1 || data['model'] != modelId) {
      throw const FormatException('Incompatible face reference');
    }
    final vector = (data['reference'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    final threshold = (data['threshold'] as num).toDouble();
    if (vector.length != 192 ||
        !threshold.isFinite ||
        threshold < 0.04 ||
        threshold > 0.20) {
      throw const FormatException('Invalid face reference');
    }
    return FaceEnrollmentProfile(normalizeFaceEmbedding(vector), threshold);
  }

  Future<void> delete() => storage.delete(key: _key);
}
