import 'package:flutter/foundation.dart';

/// Turns whatever someone typed into a websocket URL.
///
/// `192.168.1.20:8787` and `http://192.168.1.20:8787` both become
/// `ws://192.168.1.20:8787`.
String normalizeServerUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return '';
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  final lower = value.toLowerCase();
  if (lower.startsWith('http://')) {
    value = 'ws://${value.substring('http://'.length)}';
  } else if (lower.startsWith('https://')) {
    value = 'wss://${value.substring('https://'.length)}';
  } else if (!value.contains('://')) {
    value = 'ws://$value';
  }
  return value;
}

String? validateServerUrl(String input) {
  final normalized = normalizeServerUrl(input);
  if (normalized.isEmpty) return 'Enter the server address first.';
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'ws' && uri.scheme != 'wss')) {
    return "That server address doesn't look right.";
  }
  return null;
}

String? validateName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  final pattern = RegExp(
    r"^[\p{L}\p{N}][\p{L}\p{N} '’\-]{0,15}$",
    unicode: true,
  );
  if (!pattern.hasMatch(name)) {
    return 'Use 1–16 letters or numbers for your name.';
  }
  return null;
}

/// Android emulator reaches the host machine at 10.0.2.2.
/// A phone on the same Wi-Fi should replace this with the computer's LAN address.
String defaultServerUrl() {
  if (kIsWeb) {
    final host = Uri.base.host;
    final name = host.isEmpty ? 'localhost' : host;
    return 'ws://$name:8787';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'ws://10.0.2.2:8787';
  }
  return 'ws://localhost:8787';
}
