import 'dart:typed_data';

class FaceEmbeddingBackend {
  Future<void> initialize() async => throw UnsupportedError('Android only');
  List<double> embed(Float32List rgb) => throw UnsupportedError('Android only');
  void dispose() {}
}
