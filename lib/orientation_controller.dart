import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class OrientationController extends ChangeNotifier with WidgetsBindingObserver {
  static const channel = EventChannel('privacy_screen/orientation');
  StreamSubscription<dynamic>? _subscription;
  double thetaThreshold = 60;
  double phiThreshold = 60;
  double? _theta;
  double? _yaw;
  double _thetaOrigin = 0;
  double? _yawOrigin;
  String? error;
  bool _disposed = false;
  bool _active = true;

  bool get ready => _theta != null && _yaw != null && error == null;
  double? get theta => _theta == null ? null : _theta! - _thetaOrigin;
  double? get phi => _yaw == null || _yawOrigin == null
      ? null
      : math.atan2(
          math.sin(_yaw! - _yawOrigin!),
          math.cos(_yaw! - _yawOrigin!),
        );
  bool get triggered =>
      ready &&
      (theta!.abs() * 180 / math.pi > thetaThreshold + 1e-9 ||
          phi!.abs() * 180 / math.pi > phiThreshold + 1e-9);
  bool get protected => !ready || triggered;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void _listen() {
    if (_subscription != null || _disposed) return;
    _subscription = channel.receiveBroadcastStream().listen(
      (event) {
        if (_disposed || !_active) return;
        final values = Map<Object?, Object?>.from(event as Map);
        _theta = (values['theta'] as num).toDouble();
        _yaw = (values['phi'] as num).toDouble();
        _yawOrigin ??= _yaw;
        error = null;
        notifyListeners();
      },
      onError: (Object failure) {
        if (_disposed) return;
        error = failure is PlatformException
            ? failure.message ?? 'Motion sensors unavailable.'
            : 'Motion sensors unavailable on this device.';
        notifyListeners();
      },
    );
  }

  void setThresholds(double theta, double phi) {
    thetaThreshold = theta.clamp(0, 180);
    phiThreshold = phi.clamp(0, 180);
    notifyListeners();
  }

  void calibrate() {
    if (!ready) return;
    _thetaOrigin = _theta!;
    _yawOrigin = _yaw;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      _listen();
    } else {
      _active = false;
      _theta = null;
      _yaw = null;
      _yawOrigin = null;
      final subscription = _subscription;
      _subscription = null;
      subscription?.cancel();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}
