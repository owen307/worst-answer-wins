import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';
import 'server_url.dart';

const _serverKey = 'worst_answer_wins.server_url';

class GameController extends ChangeNotifier {
  GameController({
    String? initialUrl,
    this.rememberServer = true,
    RoomState? initialRoom,
  }) : serverUrl = initialUrl ?? defaultServerUrl(),
       room = initialRoom;

  final bool rememberServer;

  String serverUrl;
  RoomState? room;
  String? error;
  bool connecting = false;
  bool reconnecting = false;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pendingTimer;
  int _generation = 0;
  bool _intentionalLeave = false;

  Future<void> loadSavedServer() async {
    if (!rememberServer) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_serverKey);
      if (saved != null && saved.trim().isNotEmpty) {
        serverUrl = normalizeServerUrl(saved);
        notifyListeners();
      }
    } catch (_) {
      // Settings are optional. The typed address still works.
    }
  }

  void updateServerUrl(String value) {
    if (value == serverUrl) return;
    serverUrl = value;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  Future<void> createRoom({required String name, required int rounds}) {
    return _sendFirst({
      'type': 'create',
      'name': name.trim(),
      'rounds': rounds,
    });
  }

  Future<void> joinRoom({required String code, required String name}) {
    return _sendFirst({
      'type': 'join',
      'code': code.trim(),
      'name': name.trim(),
    });
  }

  void startGame() => _send({'type': 'start'});

  void submitAnswer(String text) => _send({'type': 'submit', 'text': text});

  void vote(String answerId) => _send({'type': 'vote', 'answerId': answerId});

  void lockPhase() => _send({'type': 'lock'});

  void nextRound() => _send({'type': 'next'});

  void playAgain() => _send({'type': 'again'});

  void leave() {
    _intentionalLeave = true;
    _generation += 1;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _pendingTimer?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode({'type': 'leave'}));
      } catch (_) {
        // The socket is already gone.
      }
      unawaited(channel.sink.close());
    }
    room = null;
    connecting = false;
    reconnecting = false;
    error = null;
    notifyListeners();
  }

  /// Drops a host/join attempt that never reached a room.
  void abandonAttempt() {
    if (room != null) return;
    _intentionalLeave = true;
    _generation += 1;
    _pendingTimer?.cancel();
    _pingTimer?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(channel.sink.close());
    }
    connecting = false;
    reconnecting = false;
    notifyListeners();
  }

  Future<void> _sendFirst(Map<String, Object?> message) async {
    _intentionalLeave = false;
    error = null;
    connecting = true;
    reconnecting = false;
    notifyListeners();
    final opened = await _openSocket();
    if (!opened) return;
    _send(message);
    _armPendingTimer();
  }

  void _armPendingTimer() {
    _pendingTimer?.cancel();
    _pendingTimer = Timer(const Duration(seconds: 8), () {
      if (connecting && room == null) {
        connecting = false;
        error ??= "The server didn't answer. Check the address and try again.";
        notifyListeners();
      }
    });
  }

  Future<bool> _openSocket() async {
    final problem = validateServerUrl(serverUrl);
    if (problem != null) {
      error = problem;
      connecting = false;
      notifyListeners();
      return false;
    }
    final normalized = normalizeServerUrl(serverUrl);
    serverUrl = normalized;
    final generation = ++_generation;
    final previous = _channel;
    _channel = null;
    if (previous != null) {
      unawaited(previous.sink.close());
    }

    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(normalized));
    } catch (_) {
      if (generation != _generation) return false;
      error = "That server address doesn't look right.";
      connecting = false;
      notifyListeners();
      return false;
    }
    _channel = channel;
    channel.stream.listen(
      (message) {
        if (generation != _generation) return;
        _onMessage(message);
      },
      onError: (Object _) {
        if (generation != _generation || _intentionalLeave) return;
        _handleDrop();
      },
      onDone: () {
        if (generation != _generation || _intentionalLeave) return;
        _handleDrop();
      },
    );

    try {
      await channel.ready.timeout(const Duration(seconds: 8));
    } catch (_) {
      if (generation != _generation) return false;
      error = "Can't reach the server at $serverUrl.";
      connecting = false;
      notifyListeners();
      if (room != null) _scheduleReconnect();
      return false;
    }
    if (generation != _generation) return false;
    unawaited(_persistServer());
    _startPing(generation);
    return true;
  }

  void _startPing(int generation) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (generation != _generation) return;
      _send({'type': 'ping'});
    });
  }

  void _handleDrop() {
    connecting = false;
    if (room == null) {
      error ??= "Can't reach the server at $serverUrl.";
      notifyListeners();
      return;
    }
    reconnecting = true;
    error = "Reconnecting to the party…";
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalLeave || room == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      if (_intentionalLeave || room == null) return;
      final opened = await _openSocket();
      if (!opened || room == null) return;
      _send({
        'type': 'resume',
        'code': room!.code,
        'playerId': room!.you.id,
        'token': room!.you.token,
      });
    });
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) return;
      message = decoded;
    } catch (_) {
      return;
    }
    if (message['type'] == 'pong') return;
    if (message['type'] == 'error') {
      error = message['message'] as String? ?? 'Something went wrong.';
      connecting = false;
      notifyListeners();
      return;
    }
    if (message['type'] == 'state') {
      final payload = message['room'];
      if (payload is! Map<String, dynamic>) return;
      room = RoomState.fromJson(payload);
      error = null;
      connecting = false;
      reconnecting = false;
      _pendingTimer?.cancel();
      notifyListeners();
    }
  }

  void _send(Map<String, Object?> message) {
    final channel = _channel;
    if (channel == null) {
      error = "Can't reach the server at $serverUrl.";
      notifyListeners();
      return;
    }
    try {
      channel.sink.add(jsonEncode(message));
    } catch (_) {
      _handleDrop();
    }
  }

  Future<void> _persistServer() async {
    if (!rememberServer) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverKey, serverUrl);
    } catch (_) {
      // Ignore. The in-memory address is enough for this session.
    }
  }

  @override
  void dispose() {
    _generation += 1;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _pendingTimer?.cancel();
    unawaited(_channel?.sink.close());
    super.dispose();
  }
}
