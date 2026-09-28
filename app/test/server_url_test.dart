import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worst_answer_wins/server_url.dart';

void main() {
  test('normalizeServerUrl accepts party-friendly addresses', () {
    expect(normalizeServerUrl('  192.168.1.20:8787 '), 'ws://192.168.1.20:8787');
    expect(normalizeServerUrl('http://localhost:8787'), 'ws://localhost:8787');
    expect(normalizeServerUrl('https://party.example/game/'), 'wss://party.example/game');
    expect(normalizeServerUrl('ws://localhost:8787'), 'ws://localhost:8787');
    expect(normalizeServerUrl(''), '');
  });

  test('validateName keeps display names short and plain', () {
    expect(validateName('Ava'), isNull);
    expect(validateName('  Noah  '), isNull);
    expect(validateName(''), isNotNull);
    expect(validateName('This Name Is Way Too Long'), isNotNull);
  });

  test('android emulator defaults to the host loopback alias', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(defaultServerUrl(), 'ws://10.0.2.2:8787');
  });
}
