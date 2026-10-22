import 'package:flutter_test/flutter_test.dart';
import 'package:nba_games/models/nba_game_model.dart';

void main() {
  test('NbaGame.fromSohu parses home/away fields', () {
    final game = NbaGame.fromSohu({
      'id': 1,
      'column_2_text': '热火',
      'column_5_text': '森林狼',
      'column_3_text': '85',
      'column_6_text': '104',
      'brief': '07:30',
      'column_11_text': '进行中',
      'column_7_text': 'NBA 常规赛',
      'url': 'http://m.sohu.com/xtopic/TURBeE5EZzVNVEF4',
    });

    expect(game.homeTeam, '热火');
    expect(game.awayTeam, '森林狼');
    expect(game.homeScore, '85');
    expect(game.awayScore, '104');
    expect(game.topicId, 'TURBeE5EZzVNVEF4');
    expect(game.isLive, isTrue);
  });
}
