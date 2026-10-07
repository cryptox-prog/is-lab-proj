import 'dart:async';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

import 'face_monitor.dart';

class DesktopFaceMonitor implements FaceMonitor {
  final _counts = StreamController<int>.broadcast();
  FaceDetector? _detector;
  CameraController? _camera;
  Future<void>? _processing;
  final _clock = Stopwatch()..start();
  int _lastFrame = -200;
  bool _disposed = false;

  @override
  Stream<int> get counts => _counts.stream;

  @override
  Future<void> start() async {
    if (_disposed || _camera != null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No webcam is available.');
    final front = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    final camera = CameraController(
      front.isEmpty ? cameras.first : front.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    _camera = camera;
    try {
      await camera.initialize();
      _detector ??= await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
        minFaceSize: 0.08,
      );
      await camera.startImageStream((frame) {
        if (_disposed ||
            _camera != camera ||
            _processing != null ||
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
      final faces = await _detector!.detectFacesFromCameraImage(
        frame,
        mode: FaceDetectionMode.fast,
        maxDim: 640,
      );
      if (!_disposed && _camera == camera) _counts.add(faces.length);
    } catch (error) {
      if (!_disposed && _camera == camera) _counts.addError(error);
    }
  }

  @override
  Future<void> stop() async {
    final camera = _camera;
    _camera = null;
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
    await _detector?.dispose();
    await _counts.close();
  }
}
