import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worst_answer_wins/game_controller.dart';
import 'package:worst_answer_wins/main.dart';
import 'package:worst_answer_wins/models.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, GameController controller) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(WorstAnswerApp(controller: controller));
  }

  GameController controllerFor(RoomState? room) {
    return GameController(
      initialUrl: 'ws://localhost:8787',
      rememberServer: false,
      initialRoom: room,
    );
  }

  testWidgets('home offers host and join', (tester) async {
    await pumpApp(tester, controllerFor(null));
    expect(find.text('Worst Answer Wins'), findsOneWidget);
    expect(find.text('Host a party'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    expect(find.byKey(const Key('server-url')), findsOneWidget);
  });

  testWidgets('host sheet asks for a name and a round count', (tester) async {
    await pumpApp(tester, controllerFor(null));
    await tester.tap(find.text('Host a party'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-name')), findsOneWidget);
    expect(find.text('How many rounds?'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('Open the room'));
    await tester.pump();
    expect(find.textContaining('Use 1–16'), findsOneWidget);
  });

  testWidgets('join sheet asks for a code', (tester) async {
    await pumpApp(tester, controllerFor(null));
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-name')), 'Noah');
    await tester.tap(find.text('Hop in'));
    await tester.pump();
    expect(find.text('Enter the 4-letter room code.'), findsOneWidget);
  });

  testWidgets('lobby shows the code and waits for a second player', (tester) async {
    await pumpApp(tester, controllerFor(_room()));
    expect(find.text('GRAB'), findsNothing);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Need one more player'), findsOneWidget);
    expect(find.text('Ava'), findsOneWidget);
  });

  testWidgets('host can start once two players are in', (tester) async {
    final controller = controllerFor(
      _room(
        players: [
          _player('p1', 'Ava', host: true),
          _player('p2', 'Noah'),
        ],
      ),
    );
    await pumpApp(tester, controller);
    await tester.tap(find.text('Start the nonsense'));
    await tester.pump();
    expect(controller.error, contains('reach the server'));
  });

  testWidgets('submit screen shows the prompt and sends an answer tap', (tester) async {
    final controller = controllerFor(
      _room(
        phase: 'submit',
        round: 1,
        prompt: "What's the real reason grandma's Wi-Fi is slow?",
        players: [
          _player('p1', 'Ava', host: true),
          _player('p2', 'Noah'),
        ],
      ),
    );
    await pumpApp(tester, controller);
    expect(
      find.text("What's the real reason grandma's Wi-Fi is slow?"),
      findsOneWidget,
    );
    expect(find.text('Send it'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('answer-field')),
      'The router is taking a nap.',
    );
    await tester.pump();
    await tester.tap(find.text('Send it'));
    await tester.pump();
    expect(controller.error, contains('reach the server'));
  });

  testWidgets('you cannot vote for your own answer', (tester) async {
    final controller = controllerFor(
      _room(
        phase: 'vote',
        round: 2,
        prompt: 'Why is there a single sneaker on the roof?',
        answers: const [
          AnswerState(
            id: 'a1',
            text: 'The wind wanted a souvenir.',
            yours: true,
            authorName: null,
            votes: 0,
          ),
          AnswerState(
            id: 'a2',
            text: 'The goldfish is streaming.',
            yours: false,
            authorName: null,
            votes: 0,
          ),
        ],
        players: [
          _player('p1', 'Ava', host: true),
          _player('p2', 'Noah'),
        ],
      ),
    );
    await pumpApp(tester, controller);
    expect(find.text("That's yours"), findsOneWidget);
    expect(find.text('Still picking: Ava, Noah'), findsOneWidget);
    expect(find.textContaining('by '), findsNothing);

    await tester.tap(find.text("That's yours"));
    await tester.pump();
    expect(controller.error, isNull);

    await tester.tap(find.text('The goldfish is streaming.'));
    await tester.pump();
    expect(controller.error, contains('reach the server'));
  });

  testWidgets('final screen crowns the high score', (tester) async {
    await pumpApp(
      tester,
      controllerFor(
        _room(
          phase: 'final',
          round: 3,
          players: [
            _player('p1', 'Ava', host: true, score: 4),
            _player('p2', 'Noah', score: 2),
          ],
        ),
      ),
    );
    expect(find.text('Worst answer wins'), findsOneWidget);
    expect(find.text('Ava wrote the worst ones.'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });
}

RoomState _room({
  String phase = 'lobby',
  int round = 0,
  String? prompt,
  String? yourAnswer,
  String? yourVote,
  List<PlayerState>? players,
  List<AnswerState> answers = const [],
  int submittedCount = 0,
}) {
  return RoomState(
    code: 'GRAB',
    phase: phase,
    round: round,
    totalRounds: 3,
    prompt: prompt,
    you: const YouState(
      id: 'p1',
      token: 'TOKEN',
      name: 'Ava',
      isHost: true,
      score: 0,
    ),
    players: players ?? [_player('p1', 'Ava', host: true)],
    answers: answers,
    yourAnswer: yourAnswer,
    yourVote: yourVote,
    submittedCount: submittedCount,
  );
}

PlayerState _player(
  String id,
  String name, {
  bool host = false,
  int score = 0,
  bool submitted = false,
  bool voted = false,
}) {
  return PlayerState(
    id: id,
    name: name,
    score: score,
    connected: true,
    isHost: host,
    submitted: submitted,
    voted: voted,
  );
}
