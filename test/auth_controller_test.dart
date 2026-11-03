import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_screen_software/auth_controller.dart';

class MemoryAuthStore implements AuthSecureStore {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Storage failed');
    values[key] = value;
  }
}

void main() {
  late MemoryAuthStore store;
  late AuthController auth;
  late DateTime now;
  setUp(() async {
    store = MemoryAuthStore();
    now = DateTime.utc(2026);
    auth = AuthController(store: store, now: () => now);
    await auth.initialize();
  });
  tearDown(() => auth.dispose());

  Future<void> enroll() async {
    expect(await auth.setPin('123456', '123456'), isTrue);
    auth.updateThreat(false, canPinUnlock: true);
  }

  test('starts protected; setup requires matching six digit PIN', () async {
    expect(auth.state, AuthState.unconfigured);
    auth.updateThreat(false, canPinUnlock: true);
    expect(auth.locked, isTrue);
    expect(await auth.setPin('12345', '12345'), isFalse);
    expect(await auth.setPin('123456', '654321'), isFalse);
    expect(await auth.setPin('abcdef', 'abcdef'), isFalse);
    expect(store.values, isEmpty);
    await enroll();
    expect(auth.locked, isTrue);
    final record = jsonDecode(store.values[AuthController.storageKey]!) as Map;
    expect(
      record.keys,
      unorderedEquals(['salt', 'hash', 'iterations', 'failures', 'retryUntil']),
    );
    expect(base64Decode(record['salt'] as String), hasLength(32));
    expect(base64Decode(record['hash'] as String), hasLength(32));
    expect(record['iterations'], AuthController.iterations);
    expect(record.values, isNot(contains('123456')));
    expect(await auth.setPin('654321', '654321'), isFalse);
  });

  test(
    'threat latches after safe signals and only correct PIN restores',
    () async {
      await enroll();
      expect(await auth.verifyPin('123456'), isTrue);
      expect(auth.unlocked, isTrue);
      auth.updateThreat(true, canPinUnlock: false);
      expect(auth.locked, isTrue);
      auth.updateThreat(false, canPinUnlock: true);
      expect(auth.state, AuthState.reauthenticationRequired);
      expect(await auth.verifyPin('999999'), isFalse);
      expect(auth.locked, isTrue);
      expect(await auth.verifyPin('123456'), isTrue);
    },
  );

  test('physical danger blocks correct PIN and authorized face', () async {
    await enroll();
    auth.updateThreat(true, canPinUnlock: false);
    expect(await auth.verifyPin('123456'), isFalse);
    expect(auth.authorizeFace(), isFalse);
    expect(auth.locked, isTrue);
  });

  test('PIN overrides unknown identity for current session only', () async {
    await enroll();
    auth.updateThreat(true, canPinUnlock: true);
    expect(auth.authorizeFace(), isFalse);
    final verification = auth.verifyPin('123456');
    auth.updateThreat(true, canPinUnlock: true);
    expect(await verification, isTrue);
    auth.updateThreat(true, canPinUnlock: true);
    expect(auth.unlocked, isTrue);
    auth.invalidatePinSession();
    expect(auth.locked, isTrue);
    auth.updateThreat(false, canPinUnlock: true);
    expect(auth.locked, isTrue);
    expect(auth.authorizeFace(), isTrue);
    auth.updateThreat(true, canPinUnlock: true);
    expect(auth.locked, isTrue);
  });

  test(
    'three failures persist a thirty second cooldown across restart',
    () async {
      await enroll();
      for (var i = 0; i < 3; i++) {
        expect(await auth.verifyPin('000000'), isFalse);
      }
      expect(auth.retryAfter, const Duration(seconds: 30));
      auth.dispose();
      auth = AuthController(store: store, now: () => now);
      await auth.initialize();
      auth.updateThreat(false, canPinUnlock: true);
      expect(await auth.verifyPin('123456'), isFalse);
      expect(auth.locked, isTrue);
      now = now.add(const Duration(seconds: 31));
      expect(await auth.verifyPin('123456'), isTrue);
    },
  );

  test(
    'sensor threat during PIN derivation cancels in-flight authorization',
    () async {
      await enroll();
      final verification = auth.verifyPin('123456');
      auth.updateThreat(true, canPinUnlock: false);
      auth.updateThreat(false, canPinUnlock: true);
      expect(await verification, isFalse);
      expect(auth.locked, isTrue);
    },
  );

  test(
    'storage failure cannot reveal content or silently replace PIN',
    () async {
      await enroll();
      store.failWrites = true;
      expect(await auth.verifyPin('123456'), isFalse);
      expect(auth.locked, isTrue);
    },
  );

  test(
    'malformed stored credential fails closed instead of offering reset',
    () async {
      store.values[AuthController.storageKey] = '{broken';
      auth.dispose();
      auth = AuthController(store: store);
      await auth.initialize();
      expect(auth.initialized, isFalse);
      expect(auth.locked, isTrue);
      expect(await auth.setPin('123456', '123456'), isFalse);
    },
  );
}
