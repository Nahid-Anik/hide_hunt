import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/features/hunt/domain/match.dart';
import 'dart:ui' show Color, Rect;
import 'package:hide_hunt_flutter/features/hunt/domain/models/arena.dart';
import 'package:hide_hunt_flutter/features/hunt/domain/models/prop.dart';

const field = Arena('Test', Color(0xffaabbcc), []);
Match match(int human) {
  final m = Match(field, human, 42)..hiding = false;
  m.players[0].at = const Offset(400, 350);
  m.players[1].at = const Offset(450, 350);
  m.players[2].caught = true;
  m.players[3].caught = true;
  return m;
}

void main() {
  test(
    'capture hits at its drawn radius, starts pulse, and respects cooldown',
    () {
      final m = match(0);
      m.players[1].at = m.players[0].at + const Offset(75, 0);
      expect(m.primary(0), isTrue);
      expect(m.players[1].caught, isTrue);
      expect(m.captureHit, isTrue);
      expect(m.captureEffect, Match.captureEffectDuration);
      expect(m.captureOrigin, const Offset(400, 350));
      expect(m.primary(0), isFalse);
      for (var i = 0; i < 14; i++) {
        m.tick(.05, Offset.zero);
      }
      expect(m.captureEffect, 0);
    },
  );
  test('capture miss still shows pulse and does not catch outside radius', () {
    final m = match(0);
    m.players[1].at = const Offset(476, 350);
    expect(m.primary(0), isTrue);
    expect(m.captureHit, isFalse);
    expect(m.captureEffect, greaterThan(0));
    expect(m.players[1].caught, isFalse);
  });
  test('walls block capture and entering objects', () {
    final m = Match(
      const Arena('Wall', Color(0xffaabbcc), [
        Rect.fromLTWH(425, 300, 10, 100),
      ]),
      0,
      1,
    )..hiding = false;
    m.players[0].at = const Offset(410, 350);
    m.players[1].at = const Offset(450, 350);
    m.players[2].caught = true;
    m.players[3].caught = true;
    m.primary(0);
    expect(m.captureHit, isFalse);
    m.props
      ..clear()
      ..add(Prop(const Offset(410, 350), 1));
    expect(m.primary(1), isFalse);
  });
  test(
    'hide occupies existing object without adding props, remains capturable',
    () {
      final m = match(0);
      final object = Prop(const Offset(455, 350), 1);
      m.props
        ..clear()
        ..add(object);
      expect(m.primary(1), isTrue);
      expect(m.players[1].hidingIn, same(object));
      expect(m.players[1].at, object.at);
      expect(m.props.length, 1);
      expect(m.visible(1), isFalse);
      m.primary(0);
      expect(m.players[1].caught, isTrue);
      expect(m.players[1].hidingIn, isNull);
    },
  );
  test('moving exits hiding, and another rebel cannot occupy same object', () {
    final m = match(1)..hiding = true;
    m.props
      ..clear()
      ..add(Prop(const Offset(450, 350), 0));
    m.primary(1);
    m.players[2]
      ..caught = false
      ..at = const Offset(450, 350);
    expect(m.primary(2), isFalse);
    m.players[2].caught = true;
    m.tick(.05, Offset.zero);
    expect(m.players[1].hidingIn, isNotNull);
    m.tick(.05, const Offset(1, 0));
    expect(m.players[1].hidingIn, isNull);
    expect(m.players[1].at.dx, greaterThan(450));
  });
  test(
    'vanish hides for three seconds, blocks sense, and has a twenty-second cooldown',
    () {
      final m = match(0);
      m.secondary(1);
      expect(m.players[1].vanish, 3);
      expect(m.players[1].skill, 20);
      expect(m.visible(1), isFalse);
      expect(m.secondary(0), 'Nothing nearby.');
      expect(m.secondary(1), isEmpty);
      // Keep the bot stationary in an object while its timer runs.
      m.props
        ..clear()
        ..add(Prop(m.players[1].at, 0));
      m.primary(1);
      for (var i = 0; i < 59; i++) {
        m.tick(.05, Offset.zero);
      }
      expect(m.players[1].vanish, greaterThan(0));
      m.tick(.05, Offset.zero);
      expect(m.players[1].vanish, closeTo(0, 1e-8));
      expect(m.players[1].skill, greaterThan(0));
      m.tick(.05, Offset.zero);
      m.primary(1);
      expect(m.visible(1), isTrue);
    },
  );
  test('vanish lets a rebel leave, move and hide again before expiry', () {
    final m = match(1)..hiding = true;
    m.props
      ..clear()
      ..add(Prop(const Offset(450, 350), 0));
    m.primary(1);
    m.secondary(1);
    expect(m.players[1].hidingIn, isNull);
    m.tick(.05, const Offset(1, 0));
    expect(m.players[1].at.dx, greaterThan(450));
    expect(m.visible(1), isTrue);
    expect(m.primary(1), isTrue);
    expect(m.players[1].vanish, greaterThan(0));
    expect(m.players[1].hidingIn, isNotNull);
  });
  test('vanish grants invisibility but not capture immunity', () {
    final m = match(0);
    m.secondary(1);
    m.primary(0);
    expect(m.players[1].caught, isTrue);
  });
}
