import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PlatformAuthSecureStore implements AuthSecureStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

enum AuthState {
  unconfigured,
  privacyThreat,
  reauthenticationRequired,
  authorized,
}

/// Authentication is session-only; clearing a sensor threat never authorizes.
class AuthController extends ChangeNotifier {
  AuthController({AuthSecureStore? store, DateTime Function()? now})
    : _store = store ?? PlatformAuthSecureStore(),
      _now = now ?? DateTime.now;

  static const storageKey = 'privacy.auth.pin.v1';
  static const iterations = 210000;
  final AuthSecureStore _store;
  final DateTime Function() _now;
  final _pbkdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  Map<String, dynamic>? _record;
  bool _initialized = false;
  bool _authorized = false;
  bool _physicalSafe = false;
  bool _threat = true;
  bool _pinSession = false;
  bool _busy = false;
  bool _disposed = false;
  int _epoch = 0;
  String? error;

  bool get configured => _record != null;
  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get unlocked => configured && _authorized && _physicalSafe;
  bool get locked => !unlocked;
  AuthState get state => !configured
      ? AuthState.unconfigured
      : unlocked
      ? AuthState.authorized
      : !_physicalSafe || (_threat && !_pinSession)
      ? AuthState.privacyThreat
      : AuthState.reauthenticationRequired;
  Duration get retryAfter {
    final until = _record?['retryUntil'] as int? ?? 0;
    final remaining = until - _now().millisecondsSinceEpoch;
    return Duration(milliseconds: max(0, remaining));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized || _busy) return;
    _busy = true;
    try {
      final raw = await _store.read(storageKey);
      if (raw != null) {
        final record = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (record['iterations'] != iterations ||
            base64Decode(record['salt'] as String).length != 32 ||
            base64Decode(record['hash'] as String).length != 32 ||
            record['failures'] is! int ||
            record['retryUntil'] is! int) {
          throw const FormatException('Invalid PIN record');
        }
        _record = record;
      }
      _initialized = true;
      error = null;
    } catch (_) {
      error = 'Secure PIN storage unavailable. Retry authentication.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  void updateThreat(bool threat, {bool canPinUnlock = false}) {
    final invalidate =
        (!canPinUnlock && _physicalSafe) ||
        (threat && !_threat && !_pinSession);
    _threat = threat;
    _physicalSafe = canPinUnlock;
    if (!canPinUnlock || (threat && !_pinSession)) {
      if (invalidate) _epoch++;
      _authorized = false;
      if (!canPinUnlock) _pinSession = false;
    }
    _notify();
  }

  void invalidatePinSession() {
    _pinSession = false;
    _authorized = false;
    _epoch++;
    _notify();
  }

  bool authorizeFace() {
    if (!_initialized || !configured || !_physicalSafe || _threat || _busy) {
      return false;
    }
    _authorized = true;
    _pinSession = false;
    _notify();
    return true;
  }

  Future<List<int>> _derive(String pin, List<int> salt) async =>
      (await _pbkdf.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)),
        nonce: salt,
      )).extractBytes();

  Future<bool> setPin(String pin, String confirmation) async {
    if (!_initialized || configured || _busy) return false;
    if (!RegExp(r'^[0-9]{6,64}$').hasMatch(pin) || pin != confirmation) {
      error = 'Enter matching PINs of 6 to 64 digits.';
      _notify();
      return false;
    }
    _busy = true;
    _notify();
    try {
      final random = Random.secure();
      final salt = List<int>.generate(32, (_) => random.nextInt(256));
      final record = <String, dynamic>{
        'salt': base64Encode(salt),
        'hash': base64Encode(await _derive(pin, salt)),
        'iterations': iterations,
        'failures': 0,
        'retryUntil': 0,
      };
      await _store.write(storageKey, jsonEncode(record));
      _record = record;
      error = null;
      return true;
    } catch (_) {
      error = 'Unable to save PIN securely.';
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<bool> verifyPin(String pin) async {
    if (!_initialized || !configured || _busy) return false;
    if (retryAfter > Duration.zero) {
      error = 'Too many attempts. Wait 30 seconds before retrying.';
      _notify();
      return false;
    }
    _busy = true;
    final epoch = _epoch;
    _notify();
    try {
      final actual = await _derive(
        pin,
        base64Decode(_record!['salt'] as String),
      );
      final expected = base64Decode(_record!['hash'] as String);
      var difference = actual.length ^ expected.length;
      for (var i = 0; i < expected.length; i++) {
        difference |= actual[i] ^ expected[i];
      }
      final correct = difference == 0;
      final record = Map<String, dynamic>.from(_record!);
      final failures = correct ? 0 : (record['failures'] as int) + 1;
      record['failures'] = failures >= 3 ? 0 : failures;
      record['retryUntil'] = failures >= 3
          ? _now().add(const Duration(seconds: 30)).millisecondsSinceEpoch
          : 0;
      await _store.write(storageKey, jsonEncode(record));
      _record = record;
      if (!correct) {
        error = 'Incorrect PIN.';
        return false;
      }
      if (!_physicalSafe || epoch != _epoch || _disposed) {
        error = 'Wait for safe orientation and at most one face, then retry.';
        return false;
      }
      _authorized = true;
      _pinSession = true;
      error = null;
      return true;
    } catch (_) {
      error = 'Secure PIN storage unavailable. Content remains protected.';
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
