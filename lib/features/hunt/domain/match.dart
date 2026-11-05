import 'dart:math';
import 'dart:ui';
import 'arena_navigation.dart';
import 'models/arena.dart';
import 'models/pawn.dart';
import 'models/prop.dart';

class Match {
  static const captureRadius = 75.0;
  static const vanishDuration = 3.0;
  static const vanishCooldown = 20.0;
  static const captureEffectDuration = .65;
  double captureEffect = 0;
  Offset captureOrigin = Offset.zero;
  bool captureHit = false;
  late final ArenaNavigation navigation = ArenaNavigation(arena);
  final Arena arena;
  final int human;
  final Random rng;
  final List<Prop> props = [];
  final List<Pawn> players = [];
  final Map<int, Offset> targets = {};
  double time = 20;
  bool hiding = true, ended = false;
  int captures = 0;
  String winner = '';
  Match(this.arena, this.human, int seed) : rng = Random(seed) {
    for (var i = 0; i < 4; i++) {
      var at = i == 0 ? const Offset(480, 350) : Offset(90 + i * 210, 640);
      if (blocked(at)) at = const Offset(480, 640);
      players.add(Pawn(at, i == 0));
    }
    for (var n = 0; props.length < 48 && n < 10000; n++) {
      final at = Offset(
        55 + rng.nextDouble() * 850,
        55 + rng.nextDouble() * 610,
      );
      if (!blocked(at, 30) && props.every((p) => (p.at - at).distance > 49))
        props.add(Prop(at, props.length % 3));
    }
  }
  bool blocked(Offset p, [double radius = 12]) => navigation.blocked(p, radius);
  bool clear(Offset a, Offset b, [double radius = 0]) =>
      navigation.clear(a, b, radius);
  bool available(int i) => !ended && !players[i].caught && !(i == 0 && hiding);
  bool visible(int i) =>
      human != 0 ||
      i == human ||
      (!hiding &&
          players[i].hidingIn == null &&
          players[i].vanish <= 0 &&
          clear(players[human].at, players[i].at));
  bool primary(int i) {
    if (!available(i)) return false;
    final p = players[i];
    if (!p.hunter) {
      if (p.hidingIn != null) {
        p.hidingIn = null;
        return true;
      }
      final near =
          props
              .where(
                (q) =>
                    (q.at - p.at).distance < 85 &&
                    clear(p.at, q.at, 12) &&
                    !players.any(
                      (other) => !other.caught && other.hidingIn == q,
                    ),
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a.at - p.at).distance.compareTo((b.at - p.at).distance),
            );
      if (near.isEmpty) return false;
      p.hidingIn = near.first;
      p.at = near.first.at;
      return true;
    }
    if (p.cooldown > 0) return false;
    p.cooldown = 4;
    captureOrigin = p.at;
    captureEffect = captureEffectDuration;
    captureHit = false;
    final near =
        players
            .where(
              (q) =>
                  !q.hunter &&
                  !q.caught &&
                  (q.at - p.at).distance <= captureRadius &&
                  clear(p.at, q.at),
            )
            .toList()
          ..sort(
            (a, b) => (a.at - p.at).distance.compareTo((b.at - p.at).distance),
          );
    if (near.isNotEmpty) {
      near.first.caught = true;
      near.first.hidingIn = null;
      near.first.vanish = 0;
      captureHit = true;
      captures++;
      if (captures == 3) {
        ended = true;
        winner = 'Hunter';
      }
    }
    return true;
  }

  String secondary(int i) {
    if (!available(i) || players[i].skill > 0) return '';
    final p = players[i];
    p.skill = p.hunter ? 20 : vanishCooldown;
    if (p.hunter)
      return players.any(
            (q) =>
                !q.hunter &&
                !q.caught &&
                q.vanish <= 0 &&
                (p.at - q.at).distance < 210 &&
                clear(p.at, q.at),
          )
          ? 'A rebel is nearby…'
          : 'Nothing nearby.';
    p.hidingIn = null;
    p.vanish = vanishDuration;
    return 'Vanished! Hide inside another object.';
  }

  Offset spot() {
    final free = props
        .where((p) => !players.any((q) => !q.caught && q.hidingIn == p))
        .toList();
    final safe = free
        .where((p) => (p.at - players[0].at).distance > 220)
        .toList();
    final choices = safe.isNotEmpty ? safe : free;
    return choices.isEmpty
        ? props.first.at
        : choices[rng.nextInt(choices.length)].at;
  }

  Offset? route(Offset p, Offset target) => navigation.route(p, target);
  void tick(double dt, Offset input, {Map<int, Offset>? controlledInputs}) {
    if (!dt.isFinite || dt <= 0) return;
    dt = min(dt, .05);
    captureEffect = max(0, captureEffect - dt);
    if (ended) return;
    time -= dt;
    if (time <= 0) {
      if (hiding) {
        hiding = false;
        time = 180;
      } else {
        time = 0;
        ended = true;
        winner = captures >= 2 ? 'Hunter' : 'Rebels';
        return;
      }
    }
    for (var i = 0; i < 4; i++) {
      final p = players[i];
      p.cooldown = max(0, p.cooldown - dt);
      p.skill = max(0, p.skill - dt);
      p.vanish = max(0, p.vanish - dt);
      if (!available(i)) continue;
      Offset move = controlledInputs == null
          ? input
          : controlledInputs[i] ?? Offset.zero;
      if (controlledInputs == null
          ? i != human
          : !controlledInputs.containsKey(i)) {
        if (i == 0) {
          final seen = players
              .where(
                (q) =>
                    !q.hunter &&
                    !q.caught &&
                    q.hidingIn == null &&
                    q.vanish <= 0 &&
                    clear(p.at, q.at),
              )
              .toList();
          if (seen.isNotEmpty) {
            targets[i] = seen.first.at;
            if ((p.at - seen.first.at).distance <= captureRadius) primary(i);
          }
          targets[i] ??= props[rng.nextInt(props.length)].at;
          if ((p.at - targets[i]!).distance < 30) {
            primary(i);
            targets.remove(i);
          }
          if (p.cooldown == 0) primary(i);
        } else {
          final danger =
              !hiding &&
              (p.at - players[0].at).distance < 130 &&
              clear(p.at, players[0].at);
          if (p.hidingIn != null && (!danger || p.skill > 0)) continue;
          if (danger) {
            secondary(i);
            if (targets[i] == null ||
                (targets[i]! - players[0].at).distance < 220) {
              targets[i] = spot();
            }
          } else {
            targets[i] ??= spot();
          }
          if (targets[i] != null && (p.at - targets[i]!).distance < 9) {
            primaryIfUnmasked(i);
            if (p.hidingIn != null) continue;
            targets.remove(i);
          }
        }
        final target = targets[i];
        if (target == null) continue;
        final next = route(p.at, target);
        if (next == null) {
          targets.remove(i);
          continue;
        }
        move = next - p.at;
      }
      if (!move.dx.isFinite || !move.dy.isFinite) move = Offset.zero;
      if (move.distance > 1) move = move / move.distance;
      if (p.hidingIn != null && move.distance <= .1) continue;
      if (move.distance > .1) p.hidingIn = null;
      final speed = p.hunter ? 154.0 : 140.0;
      final delta = move * speed * dt;
      final x = p.at + Offset(delta.dx, 0);
      if (!blocked(x)) p.at = x;
      final y = p.at + Offset(0, delta.dy);
      if (!blocked(y)) p.at = y;
    }
  }

  void primaryIfUnmasked(int i) {
    if (players[i].hidingIn == null) primary(i);
  }
}
