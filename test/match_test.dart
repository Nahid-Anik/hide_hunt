import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/maps.dart';
import 'package:hide_hunt_flutter/match.dart';

void main() {
  test('hunter waits during hiding', () {
    final m = Match(arenas.first, 0, 1), at = m.players[0].at;
    m.tick(.05, const Offset(1, 0));
    expect(m.players[0].at, at);
    expect(m.primary(0), false);
  });
  test('two captures wait, third wins immediately', () {
    final m = Match(arenas.first, 0, 1)..hiding = false;
    for (final p in m.players) p.at = const Offset(400, 350);
    m.primary(0);
    expect(m.captures, 1);
    m.players[0].cooldown = 0;
    m.primary(0);
    expect(m.ended, false);
    expect(m.captures, 2);
    m.players[0].cooldown = 0;
    m.primary(0);
    expect(m.ended, true);
    expect(m.winner, 'Hunter');
  });
  test('timeout resolves win threshold', () {
    for (final n in [0, 1, 2]) {
      final m = Match(arenas.first, 0, 1)
        ..hiding = false
        ..time = .01
        ..captures = n;
      m.tick(.02, Offset.zero);
      expect(m.winner, n >= 2 ? 'Hunter' : 'Rebels');
    }
  });
  test('five maps have safe randomized props', () {
    expect(arenas.length, 5);
    for (final a in arenas) {
      final m = Match(a, 0, 42);
      expect(m.props.length, 48);
      for (final p in m.props) expect(m.blocked(p.at, 30), false);
    }
  });
  test('rebels see every active player', () {
    final m = Match(arenas.first, 1, 1);
    for (var i = 0; i < 4; i++) expect(m.visible(i), true);
  });
}
