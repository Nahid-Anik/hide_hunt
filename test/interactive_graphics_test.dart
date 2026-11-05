import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/features/home/home_screen.dart';
import 'package:hide_hunt_flutter/features/home/interactive_graphics.dart';

void main() {
  testWidgets(
    'menu feedback responds to hover and press without duplicating actions',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: ReactiveSurface(
                  child: FilledButton(
                    onPressed: () => taps++,
                    child: const Text('Play'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Play')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        greaterThan(1),
      );
      final touch = await tester.startGesture(
        tester.getCenter(find.text('Play')),
        pointer: 2,
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        lessThan(1),
      );
      await touch.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      await mouse.removePointer();
    },
  );

  testWidgets('reduced motion keeps menu geometry still', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ReactiveSurface(
              child: FilledButton(onPressed: () {}, child: const Text('Play')),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Play')));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await mouse.removePointer();
  });

  testWidgets('swiping selects a map and tapping a prop inspects it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SoloSetup()));
    final finder = find.byType(InteractiveArenaPreview);
    await tester.ensureVisible(finder);
    await tester.drag(finder, const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(find.text('The Orchard'), findsOneWidget);
    final preview = tester.widget<InteractiveArenaPreview>(finder);
    final prop = preview.match.props.first;
    final size = tester.getSize(finder), origin = tester.getTopLeft(finder);
    await tester.tapAt(
      origin +
          Offset(prop.at.dx / 960 * size.width, prop.at.dy / 720 * size.height),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('${['Tree', 'Crate', 'Barrel'][prop.kind]} hiding place'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
