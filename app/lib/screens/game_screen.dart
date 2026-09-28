import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_controller.dart';
import '../models.dart';
import '../party_widgets.dart';
import '../theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Future<void> _confirmAndLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PartyColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: PartyColors.ink, width: 3),
          ),
          title: const Text(
            'Leave the party?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'You can hop back in with the code if the game has not started.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    if (leave == true) widget.controller.leave();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.controller.room;
    if (room == null) {
      return const SizedBox.shrink();
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmAndLeave());
      },
      child: PartyBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  code: room.code,
                  onLeave: () => unawaited(_confirmAndLeave()),
                ),
                if (widget.controller.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: ErrorNote(message: widget.controller.error!),
                  ),
                Expanded(child: _PhaseBody(controller: widget.controller, room: room)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.code, required this.onLeave});

  final String code;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PartyColors.coral,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PartyColors.ink, width: 3),
            ),
            child: const Text(
              '?!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Room $code',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Leave party',
            onPressed: onLeave,
            iconSize: 32,
            icon: const Icon(Icons.close_rounded, color: PartyColors.ink),
          ),
        ],
      ),
    );
  }
}

class _PhaseBody extends StatelessWidget {
  const _PhaseBody({required this.controller, required this.room});

  final GameController controller;
  final RoomState room;

  @override
  Widget build(BuildContext context) {
    return switch (room.phase) {
      'submit' => _SubmitPhase(
        key: ValueKey('submit-${room.round}'),
        controller: controller,
        room: room,
      ),
      'vote' => _VotePhase(controller: controller, room: room),
      'reveal' => _RevealPhase(controller: controller, room: room),
      'final' => _FinalPhase(controller: controller, room: room),
      _ => _LobbyPhase(controller: controller, room: room),
    };
  }
}

class _LobbyPhase extends StatelessWidget {
  const _LobbyPhase({required this.controller, required this.room});

  final GameController controller;
  final RoomState room;

  @override
  Widget build(BuildContext context) {
    final ready = room.connectedCount >= 2;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const PhaseTitle(kicker: 'Lobby', title: 'Grab a phone'),
        CodeTiles(code: room.code),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: room.code));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Code copied')),
            );
          },
          child: const Text(
            'Copy code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${room.totalRounds} rounds · ${room.connectedCount} here',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ..._playerTiles(room, showScore: false),
        const SizedBox(height: 8),
        if (room.you.isHost)
          PartyButton(
            label: ready ? 'Start the nonsense' : 'Need one more player',
            onPressed: ready ? controller.startGame : null,
          )
        else
          const Text(
            'Waiting for the host to start.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _SubmitPhase extends StatefulWidget {
  const _SubmitPhase({
    super.key,
    required this.controller,
    required this.room,
  });

  final GameController controller;
  final RoomState room;

  @override
  State<_SubmitPhase> createState() => _SubmitPhaseState();
}

class _SubmitPhaseState extends State<_SubmitPhase> {
  late final TextEditingController _text = TextEditingController(
    text: widget.room.yourAnswer ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.controller.submitAnswer(text);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final waiting = room.players.where((player) => player.connected && !player.submitted);
    final sent = room.yourAnswer != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        PhaseTitle(
          kicker: 'Round ${room.round} of ${room.totalRounds}',
          title: 'Write the worst answer',
        ),
        if (room.prompt != null) PromptCard(text: room.prompt!),
        const SizedBox(height: 16),
        TextField(
          key: const Key('answer-field'),
          controller: _text,
          minLines: 3,
          maxLines: 5,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'The router is taking a nap.',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        PartyButton(
          label: sent ? 'Update answer' : 'Send it',
          onPressed: _text.text.trim().isEmpty ? null : _send,
        ),
        const SizedBox(height: 14),
        Text(
          '${room.submittedCount} of ${room.connectedCount} answers are in',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ..._playerTiles(room, showScore: true),
        if (room.you.isHost && room.submittedCount >= 2 && waiting.isNotEmpty) ...[
          const SizedBox(height: 8),
          PartyButton(
            label: 'Lock answers',
            outlined: true,
            onPressed: widget.controller.lockPhase,
          ),
        ],
      ],
    );
  }
}

class _VotePhase extends StatelessWidget {
  const _VotePhase({required this.controller, required this.room});

  final GameController controller;
  final RoomState room;

  @override
  Widget build(BuildContext context) {
    final waiting = room.players
        .where((player) => player.connected && !player.voted)
        .map((player) => player.name)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        PhaseTitle(
          kicker: 'Round ${room.round} of ${room.totalRounds}',
          title: 'Vote for the funniest',
        ),
        if (room.prompt != null) PromptCard(text: room.prompt!),
        const SizedBox(height: 16),
        for (final answer in room.answers)
          AnswerCard(
            text: answer.text,
            yours: answer.yours,
            selected: room.yourVote == answer.id,
            onTap: answer.yours ? null : () => controller.vote(answer.id),
          ),
        if (room.yourVote != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Tap another answer if you change your mind.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        if (waiting.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Still picking: ${waiting.join(', ')}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        if (room.you.isHost)
          PartyButton(
            label: 'Close voting',
            outlined: true,
            onPressed: controller.lockPhase,
          ),
      ],
    );
  }
}

class _RevealPhase extends StatelessWidget {
  const _RevealPhase({required this.controller, required this.room});

  final GameController controller;
  final RoomState room;

  @override
  Widget build(BuildContext context) {
    final ranked = room.answersByVotes;
    final topVotes = ranked.isEmpty ? 0 : ranked.first.votes;
    final lastRound = room.round >= room.totalRounds;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        PhaseTitle(
          kicker: 'Round ${room.round} of ${room.totalRounds}',
          title: 'Points, please',
        ),
        if (room.prompt != null) PromptCard(text: room.prompt!),
        const SizedBox(height: 16),
        for (final answer in ranked)
          AnswerCard(
            text: answer.text,
            yours: answer.yours,
            authorName: answer.authorName,
            votes: answer.votes,
            highlight: answer.votes > 0 && answer.votes == topVotes,
          ),
        const SizedBox(height: 4),
        ..._playerTiles(room, showScore: true),
        const SizedBox(height: 8),
        if (room.you.isHost)
          PartyButton(
            label: lastRound ? 'Show the winner' : 'Next round',
            onPressed: controller.nextRound,
          )
        else
          Text(
            lastRound
                ? 'Waiting for the host to show the winner.'
                : 'Waiting for the host to start the next round.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _FinalPhase extends StatelessWidget {
  const _FinalPhase({required this.controller, required this.room});

  final GameController controller;
  final RoomState room;

  @override
  Widget build(BuildContext context) {
    final winners = room.winners;
    final headline = switch (winners.length) {
      0 => 'Nobody scored. Still funny.',
      1 => '${winners.first.name} wrote the worst ones.',
      _ => '${_winnerNames(winners)} tied.',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const PhaseTitle(kicker: 'Game over', title: 'Worst answer wins'),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PartyColors.sun,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: PartyColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(color: PartyColors.ink, offset: Offset(4, 4)),
            ],
          ),
          child: Text(
            headline,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
        ..._playerTiles(room, showScore: true),
        const SizedBox(height: 8),
        if (room.you.isHost)
          PartyButton(label: 'Play again', onPressed: controller.playAgain)
        else
          const Text(
            'Ask the host if you want another game.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

List<Widget> _playerTiles(RoomState room, {required bool showScore}) {
  return [
    for (var i = 0; i < room.players.length; i++)
      PlayerTile(
        name: room.players[i].name,
        color: PartyColors.avatar[_colorIndex(room.players[i].name)],
        score: showScore ? room.players[i].score : null,
        host: room.players[i].isHost,
        connected: room.players[i].connected,
        badge: _badge(room.phase, room.players[i]),
      ),
  ];
}

String _winnerNames(List<PlayerState> winners) {
  if (winners.length <= 1) return winners.map((player) => player.name).join();
  if (winners.length == 2) {
    return '${winners[0].name} and ${winners[1].name}';
  }
  final head = winners
      .take(winners.length - 1)
      .map((player) => player.name)
      .join(', ');
  return '$head, and ${winners.last.name}';
}

int _colorIndex(String name) {
  final mod = name.hashCode % PartyColors.avatar.length;
  return mod < 0 ? mod + PartyColors.avatar.length : mod;
}

String? _badge(String phase, PlayerState player) {
  if (!player.connected) return 'Away';
  if (phase == 'submit') return player.submitted ? 'In' : 'Writing';
  if (phase == 'vote') return player.voted ? 'Voted' : 'Picking';
  return null;
}
