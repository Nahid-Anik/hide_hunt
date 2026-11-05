import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../domain/match.dart';
import 'arena_renderer.dart';
import '../../local/data/local_session.dart';

class HuntGame extends Game {
  final Match match;
  late final ArenaRenderer renderer = ArenaRenderer(match);
  final ValueNotifier<int> updates = ValueNotifier(0);
  final LocalSession? session;
  Offset _movement = Offset.zero;
  Offset get movement => _movement;
  set movement(Offset value) {
    _movement = value;
    session?.setMovement(value);
  }

  bool paused = false;
  double hud = 0;
  HuntGame(this.match, {this.session});
  @override
  void update(double dt) {
    if (!paused && session == null) match.tick(dt, movement);
    if (!paused && !(session?.paused ?? false) && !match.ended)
      renderer.advance(dt);
    hud += dt;
    if (hud > .05) {
      hud = 0;
      updates.value++;
    }
  }

  @override
  Color backgroundColor() => const Color(0xff203c32);
  @override
  void render(Canvas canvas) =>
      renderer.render(canvas, size, cacheScenery: true);

  @override
  void onRemove() {
    renderer.dispose();
    super.onRemove();
  }
}
