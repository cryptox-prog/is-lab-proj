import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_screen_software/face_protection_controller.dart';

import 'fake_face_monitor.dart';

void main() {
  testWidgets('Denied permission does not prompt again on resume', (
    tester,
  ) async {
    final monitor = FakeFaceMonitor();
    final controller = FaceProtectionController(monitor: monitor)..start();
    await tester.pump();
    monitor.denyPermission();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(monitor.starts, 1);
    expect(controller.protected, isTrue);
    controller.retry();
    await tester.pump();
    expect(monitor.starts, 2);
    controller.dispose();
    await tester.pump();
  });
  testWidgets('Multiple faces protect immediately and clear frames restore', (
    tester,
  ) async {
    final monitor = FakeFaceMonitor(initialCount: null);
    final controller = FaceProtectionController(monitor: monitor)..start();
    expect(controller.protected, isTrue);
    await tester.pump();
    monitor.emit(1);
    monitor.emit(1);
    expect(controller.protected, isTrue);
    monitor.emit(1);
    expect(controller.protected, isFalse);
    monitor.emit(2);
    expect(controller.protected, isTrue);
    expect(controller.faceCount, 2);
    monitor.emit(1);
    monitor.emit(2);
    monitor.emit(0);
    monitor.emit(0);
    expect(controller.protected, isTrue);
    monitor.emit(0);
    expect(controller.protected, isFalse);
    controller.dispose();
    await tester.pump();
    expect(monitor.disposed, isTrue);
  });

  testWidgets('Camera errors and stale frames protect; retry restarts camera', (
    tester,
  ) async {
    final monitor = FakeFaceMonitor();
    final controller = FaceProtectionController(monitor: monitor)..start();
    await tester.pump();
    expect(controller.protected, isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(controller.protected, isTrue);
    expect(controller.error, contains('stalled'));
    controller.retry();
    await tester.pump();
    expect(monitor.stops, 1);
    expect(monitor.starts, 2);
    expect(controller.protected, isFalse);
    monitor.fail();
    expect(controller.protected, isTrue);
    expect(controller.error, contains('denied'));
    controller.dispose();
    await tester.pump();
  });

  testWidgets('Camera stops in background and restarts on resume', (
    tester,
  ) async {
    final monitor = FakeFaceMonitor();
    final controller = FaceProtectionController(monitor: monitor)..start();
    await tester.pump();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.protected, isTrue);
    expect(monitor.stops, 1);
    monitor.emit(1);
    monitor.emit(1);
    monitor.emit(1);
    expect(controller.protected, isTrue);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(monitor.starts, 2);
    expect(controller.protected, isFalse);
    controller.dispose();
    await tester.pump();
  });
}
