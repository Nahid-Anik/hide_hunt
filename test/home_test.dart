import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/app.dart';

void main() {
  testWidgets('local play opens a lobby and validates the host address', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    await tester.tap(find.text('LOCAL PLAY'));
    await tester.pumpAndSettle();
    expect(find.text('Same room. Same hunt.'), findsOneWidget);
    expect(find.text('Host map'), findsOneWidget);
    await tester.ensureVisible(find.text('Join room'));
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the IPv4 address shown on the host phone.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
  ]) {
    testWidgets('compact menu and solo setup work at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const App());
      expect(find.text('PLAY SOLO'), findsOneWidget);
      expect(find.text('LOCAL PLAY'), findsOneWidget);
      expect(find.text('HOW TO PLAY'), findsOneWidget);
      expect(find.text('The Courtyard'), findsNothing);
      expect(find.text('Be a rebel'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('PLAY SOLO'));
      await tester.tap(find.text('PLAY SOLO'));
      await tester.pumpAndSettle();
      expect(find.text('The Courtyard'), findsOneWidget);
      final previous = find.byTooltip('Previous map');
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('Frostwood'), findsOneWidget);
      await tester.ensureVisible(find.text('Hunter'));
      await tester.tap(find.text('Hunter'));
      await tester.pumpAndSettle();
      expect(find.text('LET’S PLAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('instructions are available through the help button', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pumpAndSettle();
    expect(find.text('The chase'), findsOneWidget);
    expect(find.text('Be a rebel'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Play with friends'), 250);
    expect(find.text('Play with friends'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
