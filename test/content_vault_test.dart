import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_screen_software/content_vault.dart';

void main() {
  test('AES encrypts text and image bytes and restores them exactly', () async {
    final vault = ContentVault();
    addTearDown(vault.dispose);
    final image = Uint8List.fromList([255, 216, 255, 0, 12, 34, 56]);
    await vault.initialize({
      'text': Uint8List.fromList(utf8.encode('Private article')),
      'image': image,
    });
    expect(vault.locked, isTrue);
    expect(vault.text('text'), isNull);
    expect(vault.image('image'), isNull);
    expect(vault.ciphertext('text'), isNot(contains('Private article')));
    expect(vault.encryptedImage('image'), isNot(equals(image)));
    await vault.setLocked(false);
    expect(vault.text('text'), 'Private article');
    expect(vault.image('image'), image);
    await vault.setLocked(true);
    expect(vault.text('text'), isNull);
    expect(vault.image('image'), isNull);
    await vault.setLocked(false);
    expect(vault.text('text'), 'Private article');
    expect(vault.image('image'), image);
  });

  test('A threshold crossing cancels an in-flight restoration', () async {
    final vault = ContentVault();
    addTearDown(vault.dispose);
    await vault.initialize({
      'text': Uint8List.fromList(utf8.encode('Private')),
    });
    final restore = vault.setLocked(false);
    await vault.setLocked(true);
    await restore;
    expect(vault.locked, isTrue);
    expect(vault.text('text'), isNull);
  });

  test('Independent sessions produce different ciphertext', () async {
    final first = ContentVault();
    final second = ContentVault();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final content = {'text': Uint8List.fromList(utf8.encode('Same text'))};
    await first.initialize(content);
    await second.initialize(content);
    expect(first.ciphertext('text'), isNot(second.ciphertext('text')));
  });
}
