import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// A session-only encrypted copy; bundled assets are not modified.
class ContentVault extends ChangeNotifier {
  final _cipher = AesGcm.with256bits();
  SecretKey? _key;
  final Map<String, SecretBox> _sealed = {};
  Map<String, Uint8List>? _clear;
  bool _locked = true;
  bool _disposed = false;
  int _revision = 0;
  String? error;

  bool get locked => _locked || _clear == null;
  bool get initialized => _key != null && _sealed.isNotEmpty;
  String? text(String id) =>
      _clear?[id] == null ? null : utf8.decode(_clear![id]!);
  Uint8List? image(String id) => _clear?[id];
  List<int>? encryptedImage(String id) => _sealed[id]?.cipherText;
  String? ciphertext(String id) {
    final box = _sealed[id];
    return box == null ? null : base64Encode(box.concatenation());
  }

  Future<void> initialize(Map<String, Uint8List> content) async {
    try {
      final key = await _cipher.newSecretKey();
      final sealed = <String, SecretBox>{};
      for (final entry in content.entries) {
        sealed[entry.key] = await _cipher.encrypt(
          entry.value,
          secretKey: key,
          aad: utf8.encode(entry.key),
        );
      }
      if (_disposed) return;
      _key = key;
      _sealed.addAll(sealed);
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      error = 'Unable to prepare protected content.';
      notifyListeners();
    }
  }

  Future<void> setLocked(bool locked) async {
    if (_disposed) return;
    if (locked) {
      _revision++;
      _locked = true;
      _clear = null;
      notifyListeners();
      return;
    }
    if (!initialized || (!_locked && _clear != null)) return;
    _locked = false;
    final revision = ++_revision;
    try {
      final clear = <String, Uint8List>{};
      for (final entry in _sealed.entries) {
        clear[entry.key] = Uint8List.fromList(
          await _cipher.decrypt(
            entry.value,
            secretKey: _key!,
            aad: utf8.encode(entry.key),
          ),
        );
      }
      // A new threshold crossing must invalidate an in-flight decryption.
      if (_disposed || _locked || revision != _revision) return;
      _clear = clear;
      error = null;
      notifyListeners();
    } catch (_) {
      if (_disposed || revision != _revision) return;
      _locked = true;
      _clear = null;
      error = 'Unable to decrypt protected content.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _clear = null;
    _sealed.clear();
    _key = null;
    super.dispose();
  }
}
