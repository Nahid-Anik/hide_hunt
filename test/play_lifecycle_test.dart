import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/features/hunt/data/arenas.dart';
import 'package:hide_hunt_flutter/features/hunt/game/hunt_game.dart';
import 'package:hide_hunt_flutter/features/hunt/presentation/play_screen.dart';

void main() {
  testWidgets(
    'startup focus changes do not pause; background and manual pause remain',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(home: Play(arena: arenas.first, human: 1)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final game = tester
          .widget<GameWidget<HuntGame>>(find.byType(GameWidget<HuntGame>))
          .game!;
      expect(game.paused, isFalse);

      game.movement = const Offset(1, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(game.movement, Offset.zero);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.paused, isFalse);
      expect(find.text('Paused'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.paused, isTrue);
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(game.paused, isFalse);

      await tester.tap(find.byIcon(Icons.pause));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.paused, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
