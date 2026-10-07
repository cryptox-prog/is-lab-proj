import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'face_monitor.dart';

class FaceProtectionController extends ChangeNotifier
    with WidgetsBindingObserver {
  FaceProtectionController({FaceMonitor? monitor})
    : _monitor = monitor ?? createFaceMonitor();
  final FaceMonitor _monitor;
  StreamSubscription<int>? _subscription;
  Future<void> _operations = Future.value();
  Timer? _staleTimer;
  int? faceCount;
  String? error;
  int _clearFrames = 0;
  bool _safe = false;
  bool _active = true;
  bool _disposed = false;
  bool _permissionDenied = false;

  bool get protected => !_active || !_safe || error != null;
  String get status =>
      error ??
      (faceCount == null
          ? 'Checking camera...'
          : '$faceCount ${faceCount == 1 ? 'face' : 'faces'} detected');

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _monitor.counts.listen((count) {
      if (_disposed || !_active) return;
      faceCount = count;
      error = null;
      _armTimeout();
      if (count > 1) {
        _safe = false;
        _clearFrames = 0;
      } else {
        // Three clear detections prevent rapid decrypt/encrypt flicker.
        _safe = ++_clearFrames >= 3;
      }
      notifyListeners();
    }, onError: (Object failure) => _fail(failure));
    _queueStart();
  }

  void _armTimeout() {
    _staleTimer?.cancel();
    _staleTimer = Timer(
      const Duration(seconds: 3),
      () => _fail(StateError('Camera detection stalled. Retry camera access.')),
    );
  }

  void _fail(Object failure) {
    if (_disposed) return;
    _safe = false;
    _staleTimer?.cancel();
    _clearFrames = 0;
    faceCount = null;
    _permissionDenied =
        failure is CameraException &&
        (failure.code.startsWith('CameraAccessDenied') ||
            failure.code == 'CameraAccessRestricted');
    error = failure is CameraException
        ? failure.description ?? 'Camera access failed.'
        : failure is StateError
        ? failure.message.toString()
        : 'Face detection unavailable. Retry camera access.';
    notifyListeners();
  }

  void _queueStart() {
    _operations = _operations.then((_) async {
      if (_disposed || !_active || _permissionDenied) return;
      try {
        await _monitor.start();
        if (!_disposed && _active && error == null) _armTimeout();
      } catch (error) {
        _fail(error);
      }
    });
  }

  void retry() {
    if (_disposed) return;
    _safe = false;
    _clearFrames = 0;
    faceCount = null;
    error = null;
    _permissionDenied = false;
    _staleTimer?.cancel();
    notifyListeners();
    _operations = _operations.then((_) async {
      try {
        await _monitor.stop();
      } catch (error) {
        _fail(error);
      }
    });
    _queueStart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _safe = false;
    _clearFrames = 0;
    faceCount = null;
    _staleTimer?.cancel();
    notifyListeners();
    if (_active) {
      _queueStart();
    } else {
      _operations = _operations.then((_) async {
        try {
          await _monitor.stop();
        } catch (_) {
          /* Already protected. */
        }
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _staleTimer?.cancel();
    _subscription?.cancel();
    _operations.then((_) => _monitor.dispose()).catchError((Object _) {});
    super.dispose();
  }
}
