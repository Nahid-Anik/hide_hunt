import 'dart:ui';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/features/hunt/data/arenas.dart';
import 'package:hide_hunt_flutter/features/hunt/domain/match.dart';
import 'package:hide_hunt_flutter/features/hunt/game/arena_renderer.dart';

Future<List<int>> pixels(ArenaRenderer renderer) async {
  final recorder = PictureRecorder();
  renderer.render(Canvas(recorder), Vector2(960, 720), cacheScenery: true);
  final picture = recorder.endRecording();
  final image = await picture.toImage(960, 720);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'new effects and depth sorting do not reveal hidden or vanished rebels to hunter',
    () async {
      final m = Match(arenas.first, 0, 42)..hiding = false;
      final renderer = ArenaRenderer(m);
      addTearDown(renderer.dispose);
      for (final p in m.players.skip(1)) {
        p.caught = true;
      }
      final empty = await pixels(renderer);
      m.players[1]
        ..caught = false
        ..vanish = 3;
      expect(await pixels(renderer), orderedEquals(empty));
      m.players[1]
        ..vanish = 0
        ..hidingIn = m.props.first
        ..at = m.props.first.at;
      expect(await pixels(renderer), orderedEquals(empty));
      m.players[1]
        ..hidingIn = null
        ..at = const Offset(480, 350);
      expect(await pixels(renderer), isNot(orderedEquals(empty)));
    },
  );
  test(
    'interaction bursts do not disclose invisible players after animation updates',
    () async {
      final visible = Match(arenas.first, 0, 42)..hiding = false;
      final baseline = Match(arenas.first, 0, 42)..hiding = false;
      for (final m in [visible, baseline]) {
        for (final p in m.players.skip(1)) {
          p.caught = true;
        }
      }
      final effectRenderer = ArenaRenderer(visible),
          plainRenderer = ArenaRenderer(baseline);
      addTearDown(effectRenderer.dispose);
      addTearDown(plainRenderer.dispose);
      visible.players[1]
        ..caught = false
        ..vanish = 3;
      effectRenderer.advance(.05);
      plainRenderer.advance(.05);
      expect(
        await pixels(effectRenderer),
        orderedEquals(await pixels(plainRenderer)),
      );
      visible.players[1]
        ..vanish = 0
        ..hidingIn = visible.props.first
        ..at = visible.props.first.at;
      effectRenderer.advance(.05);
      plainRenderer.advance(.05);
      expect(
        await pixels(effectRenderer),
        orderedEquals(await pixels(plainRenderer)),
      );
    },
  );
}
