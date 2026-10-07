import 'dart:async';

import 'package:camera/camera.dart';

import 'package:privacy_screen_software/face_monitor.dart';

class FakeFaceMonitor implements FaceMonitor {
  FakeFaceMonitor({this.initialCount = 1});
  final int? initialCount;
  final _counts = StreamController<int>.broadcast(sync: true);
  int starts = 0;
  int stops = 0;
  bool disposed = false;

  @override
  Stream<int> get counts => _counts.stream;

  void emit(int count) => _counts.add(count);
  void fail() => _counts.addError(StateError('Camera access denied.'));
  void denyPermission() => _counts.addError(
    CameraException('CameraAccessDenied', 'Camera permission denied.'),
  );

  @override
  Future<void> start() async {
    starts++;
    if (initialCount != null) {
      for (var i = 0; i < 3; i++) {
        emit(initialCount!);
      }
    }
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _counts.close();
  }
}
