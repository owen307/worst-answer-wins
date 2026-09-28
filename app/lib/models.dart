class YouState {
  const YouState({
    required this.id,
    required this.token,
    required this.name,
    required this.isHost,
    required this.score,
  });

  final String id;
  final String token;
  final String name;
  final bool isHost;
  final int score;

  factory YouState.fromJson(Map<String, dynamic> json) {
    return YouState(
      id: json['id'] as String,
      token: json['token'] as String,
      name: json['name'] as String,
      isHost: json['isHost'] as bool? ?? false,
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerState {
  const PlayerState({
    required this.id,
    required this.name,
    required this.score,
    required this.connected,
    required this.isHost,
    required this.submitted,
    required this.voted,
  });

  final String id;
  final String name;
  final int score;
  final bool connected;
  final bool isHost;
  final bool submitted;
  final bool voted;

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Player',
      score: (json['score'] as num?)?.toInt() ?? 0,
      connected: json['connected'] as bool? ?? false,
      isHost: json['isHost'] as bool? ?? false,
      submitted: json['submitted'] as bool? ?? false,
      voted: json['voted'] as bool? ?? false,
    );
  }
}

class AnswerState {
  const AnswerState({
    required this.id,
    required this.text,
    required this.yours,
    required this.authorName,
    required this.votes,
  });

  final String id;
  final String text;
  final bool yours;
  final String? authorName;
  final int votes;

  factory AnswerState.fromJson(Map<String, dynamic> json) {
    return AnswerState(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      yours: json['yours'] as bool? ?? false,
      authorName: json['authorName'] as String?,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoomState {
  const RoomState({
    required this.code,
    required this.phase,
    required this.round,
    required this.totalRounds,
    required this.prompt,
    required this.you,
    required this.players,
    required this.answers,
    required this.yourAnswer,
    required this.yourVote,
    required this.submittedCount,
  });

  final String code;
  final String phase;
  final int round;
  final int totalRounds;
  final String? prompt;
  final YouState you;
  final List<PlayerState> players;
  final List<AnswerState> answers;
  final String? yourAnswer;
  final String? yourVote;
  final int submittedCount;

  int get connectedCount => players.where((player) => player.connected).length;

  List<PlayerState> get ranked {
    final copy = [...players];
    copy.sort((a, b) => b.score.compareTo(a.score));
    return copy;
  }

  List<PlayerState> get winners {
    final board = ranked;
    if (board.isEmpty) return const [];
    final top = board.first.score;
    return board.where((player) => player.score == top).toList();
  }

  List<AnswerState> get answersByVotes {
    final copy = [...answers];
    copy.sort((a, b) => b.votes.compareTo(a.votes));
    return copy;
  }

  factory RoomState.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List<dynamic>? ?? const [])
        .map((entry) => PlayerState.fromJson(entry as Map<String, dynamic>))
        .toList();
    final answers = (json['answers'] as List<dynamic>? ?? const [])
        .map((entry) => AnswerState.fromJson(entry as Map<String, dynamic>))
        .toList();
    return RoomState(
      code: json['code'] as String? ?? '',
      phase: json['phase'] as String? ?? 'lobby',
      round: (json['round'] as num?)?.toInt() ?? 0,
      totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 5,
      prompt: json['prompt'] as String?,
      you: YouState.fromJson(json['you'] as Map<String, dynamic>),
      players: players,
      answers: answers,
      yourAnswer: json['yourAnswer'] as String?,
      yourVote: json['yourVote'] as String?,
      submittedCount: (json['submittedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
