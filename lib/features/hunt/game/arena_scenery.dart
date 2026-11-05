import 'package:flutter/material.dart';
import '../domain/models/arena.dart';

enum Biome { garden, orchard, harbor, ruins, snow }

class ArenaStyle {
  final Biome biome;
  final Color ground, shade, path, stone, stoneEdge, leaves, leafLight, accent;
  const ArenaStyle(
    this.biome,
    this.ground,
    this.shade,
    this.path,
    this.stone,
    this.stoneEdge,
    this.leaves,
    this.leafLight,
    this.accent,
  );
  factory ArenaStyle.forArena(Arena arena) => switch (arena.name) {
    'The Orchard' => const ArenaStyle(
      Biome.orchard,
      Color(0xffa7bd72),
      Color(0xff78974e),
      Color(0xffc9af79),
      Color(0xff799657),
      Color(0xff426343),
      Color(0xff568b45),
      Color(0xffb8d56c),
      Color(0xffe78960),
    ),
    'Quiet Harbor' => const ArenaStyle(
      Biome.harbor,
      Color(0xffc1cbb5),
      Color(0xff8aab9f),
      Color(0xffba9c73),
      Color(0xff879e9c),
      Color(0xff526c71),
      Color(0xff538b7a),
      Color(0xff9ec7a1),
      Color(0xfff7d994),
    ),
    'Amber Ruins' => const ArenaStyle(
      Biome.ruins,
      Color(0xffdec18f),
      Color(0xffbc986d),
      Color(0xffead5a6),
      Color(0xffc29b6c),
      Color(0xff87674d),
      Color(0xffa47143),
      Color(0xffe9bd69),
      Color(0xff83bbbc),
    ),
    'Frostwood' => const ArenaStyle(
      Biome.snow,
      Color(0xffe3efea),
      Color(0xffaccacb),
      Color(0xffbbd4d6),
      Color(0xffa6bec1),
      Color(0xff6b909b),
      Color(0xff5f9790),
      Color(0xffdeeee3),
      Color(0xff89c3e0),
    ),
    _ => const ArenaStyle(
      Biome.garden,
      Color(0xffc3d697),
      Color(0xff8fb174),
      Color(0xffdfd3aa),
      Color(0xff9fb094),
      Color(0xff657e69),
      Color(0xff538b4e),
      Color(0xffbbd983),
      Color(0xffeebc8e),
    ),
  };
}

/// Decorations are flat ground markings or confined to existing walls/borders.
/// Their artwork never adds invisible collision or non-functional hiding props.
class ArenaScenery {
  final Arena arena;
  final ArenaStyle style;
  ArenaScenery(this.arena, this.style);
  void box(Canvas c, Rect r, Color color, [double radius = 0]) => c.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radius)),
    Paint()..color = color,
  );
  void line(Canvas c, Offset a, Offset b, Color color, [double width = 1]) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );

  void paint(Canvas c) {
    const bounds = Rect.fromLTWH(0, 0, 960, 720);
    c.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.ground, style.shade],
        ).createShader(bounds),
    );
    // Broad patches soften the flat playfield without masking the props.
    for (var i = 0; i < 22; i++) {
      final center = Offset(
        55 + (i * 197 % 850).toDouble(),
        50 + (i * 137 % 600).toDouble(),
      );
      final rect = Rect.fromCenter(
        center: center,
        width: 130 + (i % 4) * 24,
        height: 65,
      );
      c.drawOval(
        rect,
        Paint()
          ..color = (i.isEven ? style.shade : style.ground).withValues(
            alpha: .22,
          ),
      );
    }
    for (var i = 0; i < 220; i++) {
      final p = Offset(
        27 + (i * 137 % 902).toDouble(),
        28 + (i * 83 % 660).toDouble(),
      );
      if (style.biome == Biome.snow) {
        c.drawOval(
          Rect.fromCenter(center: p, width: 9, height: 3),
          Paint()..color = const Color(0x30ffffff),
        );
      } else if (style.biome == Biome.ruins || style.biome == Biome.harbor) {
        c.drawOval(
          Rect.fromCenter(center: p, width: 3 + i % 4.0, height: 2),
          Paint()..color = style.stoneEdge.withValues(alpha: .22),
        );
      } else {
        line(
          c,
          p,
          p + const Offset(-3, -5),
          style.leaves.withValues(alpha: .24),
          1.5,
        );
        line(
          c,
          p,
          p + const Offset(2, -6),
          style.leaves.withValues(alpha: .24),
          1.5,
        );
        if (i % 13 == 0) {
          for (final off in [
            const Offset(0, -3),
            const Offset(-2, 0),
            const Offset(2, 0),
          ]) {
            c.drawCircle(
              p + off,
              1.8,
              Paint()..color = const Color(0xffffefc6),
            );
          }
          c.drawCircle(p, 1.2, Paint()..color = style.accent);
        }
      }
    }
    _path(c);
    _border(c);
    for (final w in arena.walls) {
      _wall(c, w);
    }
  }

  void _path(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(22, 313, 916, 90),
      style.stoneEdge.withValues(alpha: .22),
      14,
    );
    box(c, const Rect.fromLTWH(22, 309, 916, 88), style.path, 14);
    if (style.biome == Biome.harbor) {
      for (var x = 28.0; x < 926; x += 24) {
        box(
          c,
          Rect.fromLTWH(x, 312, 21, 82),
          Color.lerp(style.path, Colors.white, (x.toInt() % 3) * .05)!,
          2,
        );
        line(
          c,
          Offset(x + 22, 313),
          Offset(x + 22, 393),
          const Color(0xff937c61),
        );
        line(
          c,
          Offset(x + 6, 325),
          Offset(x + 7, 376),
          const Color(0x33785739),
        );
        for (final y in [319.0, 388.0]) {
          c.drawCircle(
            Offset(x + 10, y),
            1.3,
            Paint()..color = const Color(0xff716e60),
          );
        }
      }
      return;
    }
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 23; col++) {
        final x = 30.0 + col * 40 + (row == 0 ? 0 : 8);
        final tile = Rect.fromLTWH(x, 317 + row * 38.0, 34, 32);
        box(
          c,
          tile.shift(const Offset(0, 2)),
          style.stoneEdge.withValues(alpha: .17),
          6,
        );
        box(c, tile, Color.lerp(style.path, Colors.white, col % 3 * .07)!, 6);
        line(
          c,
          tile.topLeft + const Offset(5, 2),
          tile.topRight - const Offset(5, -2),
          Colors.white.withValues(alpha: .2),
        );
        if (style.biome == Biome.ruins && col % 4 == 0) {
          final center = tile.center;
          c.drawPath(
            Path()
              ..moveTo(center.dx, center.dy - 7)
              ..lineTo(center.dx + 6, center.dy)
              ..lineTo(center.dx, center.dy + 7)
              ..lineTo(center.dx - 6, center.dy)
              ..close(),
            Paint()
              ..color = style.accent.withValues(alpha: .45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
    if (style.biome == Biome.snow) {
      for (var i = 0; i < 18; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(35 + i * 52.0, i.isEven ? 311 : 396),
            width: 53,
            height: 9,
          ),
          Paint()..color = const Color(0xffedf5ed),
        );
      }
    }
  }

  void _border(Canvas c) {
    if (style.biome == Biome.harbor) {
      final water = Paint()
        ..color = const Color(0xff4f939e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18;
      c.drawRect(const Rect.fromLTWH(8, 8, 944, 704), water);
      for (var x = 18.0; x < 950; x += 32) {
        line(c, Offset(x, 9), Offset(x + 16, 9), const Color(0xff8bc9c9), 2);
        line(
          c,
          Offset(x + 8, 711),
          Offset(x + 23, 711),
          const Color(0xff8bc9c9),
          2,
        );
      }
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(11, 11, 938, 698),
          const Radius.circular(20),
        ),
        Paint()
          ..color = style.stoneEdge.withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, 13, 934, 694),
          const Radius.circular(20),
        ),
        Paint()
          ..color = style.ground.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    // Four small corner lamps sit outside the navigable area.
    for (final p in [
      const Offset(14, 14),
      const Offset(946, 14),
      const Offset(14, 706),
      const Offset(946, 706),
    ]) {
      box(
        c,
        Rect.fromCenter(center: p, width: 14, height: 14),
        style.stoneEdge,
        4,
      );
      box(
        c,
        Rect.fromCenter(center: p - const Offset(0, 2), width: 10, height: 10),
        const Color(0xfff7d887),
        3,
      );
    }
  }

  void _wall(Canvas c, Rect w) {
    final shadow = Path()
      ..addRRect(RRect.fromRectAndRadius(w, const Radius.circular(5)));
    c.drawShadow(shadow, const Color(0x8020392e), 7, false);
    box(
      c,
      w.shift(const Offset(5, 8)),
      style.stoneEdge.withValues(alpha: .3),
      5,
    );
    box(c, w, style.stoneEdge, 5);
    final top = Rect.fromLTRB(w.left, w.top, w.right, w.bottom - 6);
    c.drawRRect(
      RRect.fromRectAndRadius(top, const Radius.circular(5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(style.stone, Colors.white, .16)!, style.stone],
        ).createShader(top),
    );
    box(
      c,
      Rect.fromLTWH(w.left + 3, w.top + 2, w.width - 6, 3),
      Colors.white.withValues(alpha: .3),
      2,
    );
    if (style.biome == Biome.orchard) {
      for (
        var n = 0.0;
        n < (w.width > w.height ? w.width : w.height);
        n += 17
      ) {
        final at = w.width > w.height
            ? Offset(w.left + n + 8, w.center.dy - 3)
            : Offset(w.center.dx, w.top + n + 7);
        c.drawCircle(
          at,
          8,
          Paint()..color = style.leaves.withValues(alpha: .38),
        );
        c.drawCircle(
          at - const Offset(2, 3),
          4,
          Paint()..color = style.leafLight.withValues(alpha: .4),
        );
      }
    } else {
      if (w.width > w.height) {
        for (var x = w.left + 29; x < w.right - 7; x += 31) {
          line(
            c,
            Offset(x, w.top + 5),
            Offset(x, w.bottom - 7),
            style.stoneEdge.withValues(alpha: .45),
            1.5,
          );
        }
      } else {
        for (var y = w.top + 26; y < w.bottom - 8; y += 28) {
          line(
            c,
            Offset(w.left + 3, y),
            Offset(w.right - 3, y),
            style.stoneEdge.withValues(alpha: .45),
            1.5,
          );
        }
      }
    }
    if (style.biome == Biome.snow) {
      box(
        c,
        Rect.fromLTWH(w.left - 1, w.top - 2, w.width + 2, 9),
        const Color(0xfff6faf0),
        5,
      );
      for (var x = w.left + 8; x < w.right - 4; x += 19) {
        c.drawPath(
          Path()
            ..moveTo(x, w.top + 6)
            ..lineTo(x + 3, w.top + 15)
            ..lineTo(x + 6, w.top + 6)
            ..close(),
          Paint()..color = const Color(0xffd6efed),
        );
      }
    } else if (style.biome == Biome.ruins) {
      final p = w.center;
      line(
        c,
        p - const Offset(5, 7),
        p + const Offset(3, 0),
        style.stoneEdge.withValues(alpha: .6),
        1.5,
      );
      line(
        c,
        p + const Offset(3, 0),
        p + const Offset(-2, 7),
        style.stoneEdge.withValues(alpha: .6),
        1.5,
      );
    } else {
      for (var i = 0; i < 3; i++) {
        final p = w.topLeft + Offset(5 + i * 4.0, 6 + (i % 2) * 4.0);
        c.drawCircle(p, 4, Paint()..color = style.leaves.withValues(alpha: .7));
      }
    }
  }
}
