import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_screen_software/desktop_face_monitor.dart';
import 'package:privacy_screen_software/face_monitor.dart';
import 'package:privacy_screen_software/orientation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS,
  ]) {
    test('Desktop $platform uses webcam protection without phone sensors', () {
      debugDefaultTargetPlatformOverride = platform;
      final orientation = OrientationController();
      expect(orientation.enabled, isFalse);
      expect(orientation.protected, isFalse);
      expect(createFaceMonitor(), isA<DesktopFaceMonitor>());
      orientation.dispose();
    });
  }
  test('Native mobile retains gyroscope protection', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final orientation = OrientationController();
    expect(orientation.enabled, isTrue);
    expect(orientation.protected, isTrue);
    expect(createFaceMonitor(), isA<CameraFaceMonitor>());
    orientation.dispose();
  });
}
