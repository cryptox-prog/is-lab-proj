import 'dart:async';
import 'dart:js_interop';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:web/web.dart' as web;

import 'face_monitor.dart';

FaceMonitor createWebFaceMonitor() => WebFaceMonitor();

class WebFaceMonitor implements FaceMonitor {
  final _counts = StreamController<int>.broadcast();
  FaceDetector? _detector;
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  Timer? _timer;
  Future<void>? _processing;
  bool _disposed = false;

  @override
  Stream<int> get counts => _counts.stream;

  @override
  Future<void> start() async {
    if (_disposed || _stream != null) return;
    if (!web.window.isSecureContext) {
      throw StateError('Camera access requires HTTPS or localhost.');
    }
    try {
      _stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: false.toJS,
              video: {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }.jsify()!,
            ),
          )
          .toDart;
      final video = web.HTMLVideoElement()
        ..muted = true
        ..autoplay = true
        ..setAttribute('playsinline', '')
        ..srcObject = _stream;
      video.style
        ..position = 'fixed'
        ..width = '1px'
        ..height = '1px'
        ..opacity = '0'
        ..pointerEvents = 'none';
      web.document.body!.appendChild(video);
      _video = video;
      await video.play().toDart;
      _detector ??= await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
        minFaceSize: 0.08,
      );
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (_disposed ||
            _video != video ||
            _processing != null ||
            video.readyState < 2) {
          return;
        }
        _processing = _detect(video).whenComplete(() => _processing = null);
      });
    } catch (error) {
      await stop();
      final message = error.toString();
      if (message.contains('NotAllowedError') ||
          message.contains('Permission denied')) {
        throw CameraException(
          'CameraAccessDenied',
          'Camera permission denied. Allow access in browser settings.',
        );
      }
      throw StateError('Unable to start webcam: $message');
    }
  }

  Future<void> _detect(web.HTMLVideoElement video) async {
    try {
      final faces = await _detector!.detectFacesFromVideo(
        video,
        mode: FaceDetectionMode.fast,
      );
      if (!_disposed && _video == video) _counts.add(faces.length);
    } catch (error) {
      if (!_disposed && _video == video) _counts.addError(error);
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
    }
    final video = _video;
    _video = null;
    video?.pause();
    video?.srcObject = null;
    video?.remove();
    await _processing;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _detector?.dispose();
    await _counts.close();
  }
}
