import 'dart:math' as math;

List<double> normalizeFaceEmbedding(List<double> values) {
  if (values.isEmpty || values.any((v) => !v.isFinite)) {
    throw const FormatException('Invalid embedding');
  }
  final norm = math.sqrt(values.fold<double>(0, (s, v) => s + v * v));
  if (norm < 1e-9) throw const FormatException('Zero embedding');
  return List.unmodifiable(values.map((v) => v / norm));
}

double faceCosineDistance(List<double> a, List<double> b) {
  if (a.length != b.length) throw const FormatException('Embedding shape');
  final x = normalizeFaceEmbedding(a);
  final y = normalizeFaceEmbedding(b);
  var dot = 0.0;
  for (var i = 0; i < x.length; i++) {
    dot += x[i] * y[i];
  }
  return 1 - dot.clamp(-1.0, 1.0);
}

class FaceEnrollmentProfile {
  final List<double> reference;
  final double threshold;
  const FaceEnrollmentProfile(this.reference, this.threshold);

  factory FaceEnrollmentProfile.fromSamples(List<List<double>> samples) {
    if (samples.length < 8 || samples.length > 20) {
      throw const FormatException('Use 8 to 20 enrollment samples');
    }
    final normalized = samples.map(normalizeFaceEmbedding).toList();
    final size = normalized.first.length;
    if (normalized.any((v) => v.length != size)) {
      throw const FormatException('Embedding shape');
    }
    final reference = normalizeFaceEmbedding(
      List.generate(
        size,
        (i) => normalized.fold<double>(0, (s, v) => s + v[i]),
      ),
    );
    // Leave-one-out distances avoid scoring a sample against its own centroid.
    final distances = <double>[];
    for (var i = 0; i < normalized.length; i++) {
      final other = normalizeFaceEmbedding(
        List.generate(size, (j) {
          var sum = 0.0;
          for (var k = 0; k < normalized.length; k++) {
            if (k != i) sum += normalized[k][j];
          }
          return sum;
        }),
      );
      distances.add(faceCosineDistance(normalized[i], other));
    }
    final mean = distances.reduce((a, b) => a + b) / distances.length;
    final sd = math.sqrt(
      distances.fold<double>(0, (s, d) => s + (d - mean) * (d - mean)) /
          distances.length,
    );
    final proposed = math.max(
      distances.reduce(math.max) + 0.02,
      mean + 3 * sd + 0.02,
    );
    // This cap is an unvalidated conservative policy, not measured FAR/TAR.
    if (proposed > 0.20) {
      throw const FormatException('Inconsistent enrollment; retry');
    }
    return FaceEnrollmentProfile(reference, proposed.clamp(0.04, 0.20));
  }
}
