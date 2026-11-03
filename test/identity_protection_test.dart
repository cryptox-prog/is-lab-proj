import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_screen_software/face_monitor.dart';
import 'package:privacy_screen_software/face_protection_controller.dart';
import 'package:privacy_screen_software/face_verification.dart';

import 'fake_face_monitor.dart';

class IdentityMonitor extends FakeFaceMonitor implements IdentityFaceMonitor {
  final events = StreamController<FaceVerificationResult>.broadcast(sync: true);
  @override
  bool get verificationSupported => true;
  @override
  bool get faceEnrolled => true;
  @override
  int identityEpoch = 0;
  @override
  Stream<FaceVerificationResult> get identities => events.stream;
  void identity(FaceVerificationStatus status) =>
      events.add(FaceVerificationResult(status));
  @override
  Future<void> beginFaceEnrollment() async {}
  @override
  Future<void> finishFaceEnrollment() async {}
  @override
  void cancelFaceEnrollment() {}
  @override
  Future<void> dispose() async {
    await super.dispose();
    await events.close();
  }
}

void main() {
  testWidgets(
    'Identity needs three matches; uncertainty and extra faces revoke it',
    (tester) async {
      final monitor = IdentityMonitor();
      final controller = FaceProtectionController(monitor: monitor)..start();
      await tester.pump();
      expect(controller.protected, isFalse);
      expect(controller.identityThreat, isTrue);
      monitor.identity(FaceVerificationStatus.authorized);
      monitor.identity(FaceVerificationStatus.authorized);
      expect(controller.identityAuthorized, isFalse);
      monitor.identity(FaceVerificationStatus.authorized);
      expect(controller.identityAuthorized, isTrue);
      monitor.identity(FaceVerificationStatus.uncertain);
      expect(controller.identityAuthorized, isFalse);
      monitor.identity(FaceVerificationStatus.unauthorized);
      expect(controller.identityThreat, isTrue);
      for (var i = 0; i < 3; i++) {
        monitor.identity(FaceVerificationStatus.authorized);
      }
      monitor.emit(2);
      expect(controller.protected, isTrue);
      expect(controller.identityAuthorized, isFalse);
      controller.dispose();
      await tester.pump();
    },
  );

  testWidgets('A changed tracked face invalidates previous authorization', (
    tester,
  ) async {
    final monitor = IdentityMonitor();
    final controller = FaceProtectionController(monitor: monitor)..start();
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      monitor.identity(FaceVerificationStatus.authorized);
    }
    expect(controller.identityAuthorized, isTrue);
    monitor.identityEpoch++;
    monitor.emit(1);
    expect(controller.identityAuthorized, isFalse);
    controller.dispose();
    await tester.pump();
  });
}
