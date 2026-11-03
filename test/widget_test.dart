import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:privacy_screen_software/main.dart';
import 'package:privacy_screen_software/auth_controller.dart';
import 'package:privacy_screen_software/face_verification.dart';

import 'fake_face_monitor.dart';
import 'identity_protection_test.dart' show IdentityMonitor;

class WidgetAuthStore implements AuthSecureStore {
  WidgetAuthStore(this.values);
  final Map<String, String> values;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = 'privacy_screen/orientation';
  const codec = StandardMethodCodec();
  final calls = <String>[];
  late FakeFaceMonitor faceMonitor;
  late AuthController auth;
  final credentials = <String, String>{};
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    final setup = AuthController(store: WidgetAuthStore(credentials));
    await setup.initialize();
    await setup.setPin('123456', '123456');
    setup.dispose();
  });
  setUp(() {
    calls.clear();
    faceMonitor = FakeFaceMonitor();
    auth = AuthController(store: WidgetAuthStore(Map.of(credentials)));
    messenger.setMockMethodCallHandler(const MethodChannel(channel), (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(channel), null);
    auth.dispose();
  });

  Future<void> unlock(WidgetTester tester) async {
    final success = await tester.runAsync(() => auth.verifyPin('123456'));
    expect(success, isTrue);
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, double theta, double phi) async {
    await messenger.handlePlatformMessage(
      channel,
      codec.encodeSuccessEnvelope({'theta': theta, 'phi': phi}),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 500 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(finder, findsWidgets);
  }

  testWidgets('Symmetric thresholds, calibration, and slider settings work', (
    tester,
  ) async {
    const channel = 'privacy_screen/orientation';
    const codec = StandardMethodCodec();
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel(channel), (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel(channel),
        null,
      ),
    );

    Future<void> send(double theta, double phi) async {
      await messenger.handlePlatformMessage(
        channel,
        codec.encodeSuccessEnvelope({'theta': theta, 'phi': phi}),
        (_) {},
      );
      await tester.pump();
    }

    await tester.pumpWidget(
      MyApp(faceMonitor: faceMonitor, authController: auth),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(calls, contains('listen'));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Calibrate'))
          .onPressed,
      isNull,
    );
    await send(math.pi / 6, 0);
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text('Within thresholds'), findsOneWidget);
    await send(math.pi / 3, 0);
    expect(find.text('Within thresholds'), findsOneWidget);
    await send(-math.pi * 61 / 180, 0);
    expect(find.text('Threshold exceeded'), findsOneWidget);
    await send(math.pi / 6, -math.pi / 2);
    expect(find.text('Threshold exceeded'), findsOneWidget);
    await send(math.pi / 6, math.pi / 2);
    expect(find.text('Threshold exceeded'), findsOneWidget);
    await tester.tap(find.text('Calibrate'));
    await tester.pump();
    expect(find.text('Within thresholds'), findsOneWidget);
    await send(math.pi / 4, math.pi * 2 / 3);
    expect(find.text('Within thresholds'), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider).first).onChanged!(10);
    await tester.pump();
    expect(find.text('Threshold exceeded'), findsOneWidget);
    await tester.tap(find.text('Calibrate'));
    await tester.pump();
    expect(find.text('Within thresholds'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('cancel')));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider).first).value, 10);
    expect(tester.widget<Slider>(find.byType(Slider).last).value, 60);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls, contains('cancel'));
  });

  testWidgets('Home screen shows dark placeholder content', (tester) async {
    await tester.pumpWidget(
      MyApp(faceMonitor: faceMonitor, authController: auth),
    );
    await send(tester, 0, 0);
    await unlock(tester);
    await waitFor(tester, find.text('Notes on everyday life'));

    expect(find.text('Privacy Screen'), findsOneWidget);
    expect(find.text('Notes on everyday life'), findsOneWidget);
    expect(find.byType(Card), findsNothing);

    await tester.dragUntilVisible(
      find.text('One last thought'),
      find.byType(ListView),
      const Offset(0, -500),
    );

    expect(find.text('One last thought'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Only fresh authorized identity results restore a face-triggered lock',
    (tester) async {
      final identityMonitor = IdentityMonitor();
      await tester.pumpWidget(
        MyApp(faceMonitor: identityMonitor, authController: auth),
      );
      await send(tester, 0, 0);
      expect(find.text('Content protected'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        identityMonitor.identity(FaceVerificationStatus.authorized);
      }
      await waitFor(tester, find.text('Notes on everyday life'));
      identityMonitor.emit(2);
      await tester.pump();
      expect(find.text('Notes on everyday life'), findsNothing);
      for (var i = 0; i < 3; i++) {
        identityMonitor.emit(1);
      }
      identityMonitor.identity(FaceVerificationStatus.unauthorized);
      await tester.pump();
      expect(auth.locked, isTrue);
      expect(find.text('Content protected'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        identityMonitor.identity(FaceVerificationStatus.authorized);
      }
      await waitFor(tester, find.text('Notes on everyday life'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Threats remove text and images; safe readings alone cannot restore them',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(
          MyApp(faceMonitor: faceMonitor, authController: auth),
        );
        expect(find.text('Notes on everyday life'), findsNothing);
        await send(tester, 0, 0);
        await unlock(tester);
        await waitFor(tester, find.text('Notes on everyday life'));
        await tester.scrollUntilVisible(find.byType(Image).first, 300);
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsWidgets);
        await send(tester, -math.pi / 2, 0);
        expect(find.byType(Image), findsNothing);
        expect(find.text('A slower start'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('Content protected'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Notes on everyday life')),
          findsNothing,
        );
        await send(tester, 0, 0);
        expect(auth.locked, isTrue);
        expect(find.byType(Image), findsNothing);
        await unlock(tester);
        await waitFor(tester, find.byType(Scrollable));
        await tester.scrollUntilVisible(find.byType(Image).first, 300);
        await tester.pumpAndSettle();
        await send(tester, 0, math.pi / 2);
        expect(find.byType(Image), findsNothing);
        await send(tester, 0, 0);
        expect(auth.locked, isTrue);
        await unlock(tester);
        await waitFor(tester, find.byType(Image));
        faceMonitor.emit(2);
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        faceMonitor.emit(1);
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        faceMonitor.emit(1);
        faceMonitor.emit(1);
        await tester.pump();
        expect(auth.locked, isTrue);
        expect(find.byType(Image), findsNothing);
        await unlock(tester);
        await waitFor(tester, find.byType(Image));
        await send(tester, math.pi / 2, 0);
        faceMonitor.emit(1);
        faceMonitor.emit(1);
        faceMonitor.emit(1);
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        await send(tester, 0, 0);
        expect(auth.locked, isTrue);
        await unlock(tester);
        await waitFor(tester, find.byType(Image));
        faceMonitor.fail();
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        semantics.dispose();
      }
    },
  );
}
