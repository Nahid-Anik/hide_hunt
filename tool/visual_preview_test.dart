// Manual visual review: flutter test tool/visual_preview_test.dart --dart-define=FLUTTER_SDK=C:/src/flutter
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_hunt_flutter/app.dart';
import 'package:hide_hunt_flutter/features/hunt/data/arenas.dart';
import 'package:hide_hunt_flutter/features/hunt/domain/match.dart';
import 'package:hide_hunt_flutter/features/hunt/game/arena_renderer.dart';

void main() {
  testWidgets('export menu and arena for visual review', (tester) async {
    const sdk = String.fromEnvironment('FLUTTER_SDK');
    await tester.runAsync(() async {
      if (sdk.isNotEmpty) {
        final loader = FontLoader('Roboto');
        for (final weight in ['regular', 'bold', 'black']) {
          final bytes = await File(
            '$sdk/bin/cache/artifacts/material_fonts/roboto-$weight.ttf',
          ).readAsBytes();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
        await loader.load();
        final iconBytes = await File(
          '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ).readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: const App()));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Directory('build/previews').create(recursive: true);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final home = await boundary.toImage(pixelRatio: 2);
      await File('build/previews/home.png').writeAsBytes(
        (await home.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      home.dispose();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final match = Match(arenas.first, 1, 42)..hiding = false;
      match.players[0].at = const Offset(420, 350);
      match.players[1].at = const Offset(480, 350);
      match.captureOrigin = match.players[0].at;
      match.captureEffect = .45;
      ArenaRenderer(match).render(canvas, Vector2(960, 720));
      final picture = recorder.endRecording();
      final arena = await picture.toImage(960, 720);
      await File('build/previews/arena.png').writeAsBytes(
        (await arena.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      arena.dispose();
      picture.dispose();
      final sheetRecorder = ui.PictureRecorder();
      final sheet = Canvas(sheetRecorder);
      sheet.drawRect(
        const Rect.fromLTWH(0, 0, 1440, 780),
        Paint()..color = const Color(0xff17382f),
      );
      for (var i = 0; i < arenas.length; i++) {
        final recorder = ui.PictureRecorder();
        final sample = Match(arenas[i], 1, 42)..hiding = false;
        final renderer = ArenaRenderer(sample);
        renderer.advance(1);
        renderer.render(Canvas(recorder), Vector2(960, 720));
        final picture = recorder.endRecording();
        final image = await picture.toImage(960, 720);
        await File('build/previews/arena_$i.png').writeAsBytes(
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List(),
        );
        final x = (i % 3) * 480.0, y = (i ~/ 3) * 390.0;
        final title = TextPainter(
          text: TextSpan(
            text: arenas[i].name,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Color(0xffffe1a3),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        title.paint(sheet, Offset(x + 12, y + 4));
        sheet.drawImageRect(
          image,
          const Rect.fromLTWH(0, 0, 960, 720),
          Rect.fromLTWH(x, y + 30, 480, 360),
          Paint(),
        );
        image.dispose();
        picture.dispose();
        renderer.dispose();
      }
      final sheetPicture = sheetRecorder.endRecording();
      final sheetImage = await sheetPicture.toImage(1440, 780);
      await File('build/previews/arenas.png').writeAsBytes(
        (await sheetImage.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      sheetImage.dispose();
      sheetPicture.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
