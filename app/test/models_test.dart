import 'package:flutter_test/flutter_test.dart';
import 'package:worst_answer_wins/models.dart';

void main() {
  test('vote snapshots stay anonymous and reveal snapshots name the author', () {
    final hidden = RoomState.fromJson({
      'code': 'GRAB',
      'phase': 'vote',
      'round': 1,
      'totalRounds': 3,
      'prompt': 'Why did the hamster start a tiny podcast?',
      'you': {
        'id': 'p1',
        'token': 'SECRET',
        'name': 'Ava',
        'isHost': true,
        'score': 0,
      },
      'players': [
        {
          'id': 'p1',
          'name': 'Ava',
          'score': 0,
          'connected': true,
          'isHost': true,
          'submitted': true,
          'voted': false,
        },
      ],
      'answers': [
        {
          'id': 'a1',
          'text': 'It had opinions about seeds.',
          'yours': true,
          'authorName': null,
          'votes': 0,
        },
      ],
      'yourAnswer': 'It had opinions about seeds.',
      'yourVote': null,
      'submittedCount': 2,
    });

    expect(hidden.answers.single.authorName, isNull);
    expect(hidden.answers.single.yours, isTrue);
    expect(hidden.you.token, 'SECRET');

    final reveal = RoomState.fromJson({
      'code': 'GRAB',
      'phase': 'reveal',
      'round': 3,
      'totalRounds': 3,
      'prompt': 'Why is the birthday cake leaning like that?',
      'you': {
        'id': 'p2',
        'token': 'OTHER',
        'name': 'Noah',
        'isHost': false,
        'score': 2,
      },
      'players': [
        {
          'id': 'p1',
          'name': 'Ava',
          'score': 4,
          'connected': true,
          'isHost': true,
          'submitted': true,
          'voted': true,
        },
        {
          'id': 'p2',
          'name': 'Noah',
          'score': 2,
          'connected': true,
          'isHost': false,
          'submitted': true,
          'voted': true,
        },
      ],
      'answers': [
        {
          'id': 'a1',
          'text': 'It wanted to sit down.',
          'yours': false,
          'authorName': 'Ava',
          'votes': 2,
        },
      ],
      'yourAnswer': 'Gravity is a critic.',
      'yourVote': 'a1',
      'submittedCount': 2,
    });

    expect(reveal.answers.single.authorName, 'Ava');
    expect(reveal.winners.single.name, 'Ava');
    expect(reveal.answersByVotes.single.votes, 2);
  });
}
