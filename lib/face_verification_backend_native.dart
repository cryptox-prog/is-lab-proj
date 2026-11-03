import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';

class FaceEmbeddingBackend {
  Interpreter? _interpreter;
  Future<void> initialize() async {
    if (_interpreter != null) return;
    final data = await rootBundle.load('assets/models/mobilefacenet.tflite');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final hash = await Sha256().hash(bytes);
    final hex = hash.bytes
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    if (hex !=
        'be4bc7cfc53f7bc336d0f28b1ab92535f618c913a422b683210750f6b5354854') {
      throw const FormatException('Face model checksum mismatch');
    }
    final options = InterpreterOptions()..threads = 2;
    final interpreter = Interpreter.fromBuffer(bytes, options: options);
    options.delete();
    if (interpreter.getInputTensor(0).shape.join(',') != '1,112,112,3' ||
        interpreter.getOutputTensor(0).shape.join(',') != '1,192') {
      interpreter.close();
      throw const FormatException('Unexpected face model tensor shape');
    }
    _interpreter = interpreter;
  }

  List<double> embed(Float32List rgb) {
    final output = [List<double>.filled(192, 0)];
    _interpreter!.run(rgb.buffer, output);
    return output.single;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
