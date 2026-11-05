import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/features/hunt/data/arenas.dart';
import 'package:hide_hunt_flutter/features/hunt/domain/match.dart';
import 'package:hide_hunt_flutter/features/hunt/domain/models/arena.dart';
import 'package:hide_hunt_flutter/features/local/data/local_session.dart';
import 'package:hide_hunt_flutter/features/local/data/match_snapshot.dart';

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline))
      throw TimeoutException('Condition not reached');
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

void main() {
  final sessions = <LocalSession>[];
  Future<LocalSession> host() async {
    final s = await LocalSession.host(
      0,
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    sessions.add(s);
    return s;
  }

  Future<LocalSession> join(LocalSession h) async {
    final s = await LocalSession.join('127.0.0.1', h.code, port: h.port);
    sessions.add(s);
    return s;
  }

  tearDown(() async {
    for (final s in sessions.reversed) {
      s.dispose();
    }
    sessions.clear();
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });

  test(
    'snapshot preserves objects, capture pulse, cooldowns, vanish and winner',
    () {
      final source = Match(arenas.first, 0, 9);
      source.players[1]
        ..at = source.props.first.at
        ..hidingIn = source.props.first
        ..vanish = 3.5
        ..skill = 12;
      source.captureOrigin = const Offset(400, 350);
      source.captureEffect = .4;
      source.captureHit = true;
      source.captures = 2;
      source.winner = 'Rebels';
      source.ended = true;
      final target = Match(arenas.first, 1, 99);
      applySnapshot(
        target,
        jsonDecode(jsonEncode(matchSnapshot(source))) as Map<String, dynamic>,
      );
      expect(matchSnapshot(target), matchSnapshot(source));
      expect(target.players[1].hidingIn, same(target.props.first));
      expect(target.human, 1);
    },
  );

  test(
    'controlled players use their own input, while empty slots remain bots',
    () {
      final m = Match(const Arena('Open', Color(0xff123456), []), 0, 1);
      final one = m.players[1].at, two = m.players[2].at;
      m.tick(
        .05,
        Offset.zero,
        controlledInputs: {
          0: Offset.zero,
          1: const Offset(1, 0),
          2: Offset.zero,
        },
      );
      expect(m.players[1].at.dx, greaterThan(one.dx));
      expect(m.players[2].at, two);
      expect(m.targets.containsKey(3), isTrue);
    },
  );

  test(
    'three simultaneous guests receive unique seats; full room and bad code reject',
    () async {
      final h = await host();
      final guests = await Future.wait([join(h), join(h), join(h)]);
      expect(guests.map((g) => g.seat).toSet(), {1, 2, 3});
      await until(() => guests.every((g) => g.members.length == 4));
      await expectLater(
        LocalSession.join('127.0.0.1', h.code, port: h.port),
        throwsStateError,
      );
      await expectLater(
        LocalSession.join('127.0.0.1', 'wrong', port: h.port),
        throwsStateError,
      );
      expect(h.members.length, 4);
    },
  );

  test(
    'remote input and abilities affect host, then snapshots reach other guests',
    () async {
      final h = await host(), a = await join(h), b = await join(h);
      h.startMatch();
      await until(() => a.started && b.started);
      expect(a.match!.human, a.seat);
      expect(a.match!.props.map((p) => p.at), h.match!.props.map((p) => p.at));
      h.match!.players[a.seat].at = const Offset(400, 350);
      a.setMovement(const Offset(1, 0));
      await until(() => h.match!.players[a.seat].at.dx > 410);
      a.setMovement(Offset.zero);
      a.action('secondary');
      await until(() => b.match!.players[a.seat].vanish > 0);
      expect(h.match!.players[a.seat].skill, greaterThan(0));
      expect(a.feedback, contains('Vanished'));
      h.setPaused(true);
      await until(() => a.paused && b.paused);
      final at = h.match!.players[a.seat].at;
      a.setMovement(const Offset(1, 0));
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(h.match!.players[a.seat].at, at);
    },
  );

  test(
    'hide and hunter capture synchronize, rematch resets every client',
    () async {
      final h = await host(), guest = await join(h);
      h.startMatch();
      await until(() => guest.started);
      final m = h.match!, p = h.match!.players[guest.seat];
      p.at = m.props.first.at;
      guest.action('primary');
      await until(
        () =>
            p.hidingIn != null &&
            guest.match!.players[guest.seat].hidingIn != null,
      );
      expect(m.visible(guest.seat), isFalse);
      m.hiding = false;
      m.players[0].at = p.at;
      h.action('primary');
      await until(() => guest.match!.captures == 1);
      expect(guest.match!.players[guest.seat].caught, isTrue);
      expect(guest.match!.captureEffect, greaterThan(0));
      await expectLater(
        LocalSession.join('127.0.0.1', h.code, port: h.port),
        throwsStateError,
      );
      m
        ..ended = true
        ..winner = 'Hunter';
      h.startMatch();
      await until(() => guest.round == 2);
      expect(guest.match!.captures, 0);
      expect(guest.match!.players[guest.seat].caught, isFalse);
      expect(guest.match!.hiding, isTrue);
    },
  );

  test(
    'disconnect frees lobby seat and converts an active player to a bot',
    () async {
      final h = await host(), first = await join(h);
      first.dispose();
      await until(() => h.members.length == 1);
      final second = await join(h);
      expect(second.seat, first.seat);
      h.startMatch();
      await until(() => second.started);
      second.dispose();
      await until(
        () => h.members.length == 1 && h.match!.targets.containsKey(1),
      );
      expect(h.error, isEmpty);
    },
  );

  test(
    'host closure produces an actionable disconnect message on guest',
    () async {
      final h = await host(), guest = await join(h);
      h.dispose();
      await until(() => guest.error.isNotEmpty);
      expect(guest.error, contains('host'));
    },
  );

  test(
    'invalid commands cannot move another seat or overwrite match state',
    () async {
      final h = await host();
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${h.port}/join?code=${h.code}&v=${LocalSession.protocolVersion}',
      );
      final received = <Map<String, dynamic>>[];
      socket.listen(
        (raw) =>
            received.add(jsonDecode(raw as String) as Map<String, dynamic>),
      );
      addTearDown(socket.close);
      await until(() => received.any((m) => m['type'] == 'welcome'));
      h.startMatch();
      h.match!.players[1].at = const Offset(400, 350);
      socket.add(jsonEncode({'type': 'input', 'x': 9999, 'y': 0, 'seat': 0}));
      await until(() => h.match!.players[1].at.dx > 400);
      expect(h.match!.players[0].at, const Offset(480, 350));
      socket.add(jsonEncode({'type': 'state', 'captures': 3}));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(h.match!.captures, 0);
      expect(h.match!.players[1].at.dx, lessThan(450));
      // No new input for >600ms: the player must stop instead of drifting forever.
      await Future<void>.delayed(const Duration(milliseconds: 650));
      final stopped = h.match!.players[1].at;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(h.match!.players[1].at, stopped);
      socket.add('not json');
      await until(() => h.members.length == 1);
      expect(h.error, isEmpty);
    },
  );
}
