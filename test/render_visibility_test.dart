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
}
