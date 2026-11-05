import 'dart:math';
import 'dart:ui' show Picture, PictureRecorder;
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import '../domain/match.dart';
import 'arena_scenery.dart';

class ArenaRenderer {
  final Match match;
  late final ArenaStyle style = ArenaStyle.forArena(match.arena);
  double animationTime = 0;
  final _positions = <int, Offset>{};
  final _stride = <int, double>{};
  final _facing = <int, double>{};
  final _moving = <int, bool>{};
  final _lastMoved = <int, double>{};
  final _bursts = <_InteractionBurst>[];
  final _previousVanish = <int, double>{};
  final _wasHidden = <int, bool>{};
  double _previousSense = 0, _senseRemaining = 0;
  Offset _senseOrigin = Offset.zero;
  Picture? _ground;
  void advance(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    dt = min(dt, .1);
    animationTime += dt;
    for (final burst in _bursts) {
      burst.remaining -= dt;
    }
    _bursts.removeWhere((burst) => burst.remaining <= 0);
    _senseRemaining = max(0, _senseRemaining - dt);
    final hunter = match.players[0];
    if (hunter.skill > _previousSense + .1) {
      _senseRemaining = 1;
      _senseOrigin = hunter.at;
    }
    _previousSense = hunter.skill;
    for (var i = 0; i < match.players.length; i++) {
      final at = match.players[i].at;
      final player = match.players[i];
      final entering = player.hidingIn != null && !(_wasHidden[i] ?? false);
      final vanishing = player.vanish > (_previousVanish[i] ?? 0) + .1;
      if ((entering || vanishing) && !player.caught && match.visible(i)) {
        _bursts.add(
          _InteractionBurst(
            i,
            at,
            vanishing ? const Color(0xffb4f4f0) : const Color(0xffffe9a6),
          ),
        );
      }
      _wasHidden[i] = player.hidingIn != null;
      _previousVanish[i] = player.vanish;
      final delta = at - (_positions[i] ?? at);
      if (delta.distance > .05) {
        _lastMoved[i] = animationTime;
        if (delta.dx.abs() > .1) _facing[i] = delta.dx.sign;
      }
      // Preserve animation between LAN snapshots instead of snapping to idle.
      _moving[i] = animationTime - (_lastMoved[i] ?? -1) < .12;
      if (_moving[i]!) _stride[i] = ((_stride[i] ?? 0) + dt * 15) % (pi * 2);
      _positions[i] = at;
    }
  }

  void dispose() {
    _ground?.dispose();
    _ground = null;
  }

  ArenaRenderer(this.match);
  void box(Canvas c, Rect r, Color color, [double radius = 0]) => c.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radius)),
    Paint()..color = color,
  );

  void label(Canvas c, String text, Offset at) {
    final t = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'Roboto',
          letterSpacing: .8,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    box(
      c,
      Rect.fromLTWH(
        at.dx - t.width / 2 - 7,
        at.dy - 3,
        t.width + 14,
        t.height + 6,
      ),
      const Color(0xd9264037),
      6,
    );
    t.paint(c, at - Offset(t.width / 2, 0));
  }

  void shadow(Canvas c, Offset at, double width, double height) => c.drawOval(
    Rect.fromCenter(center: at, width: width, height: height),
    Paint()..color = const Color(0x3021382c),
  );

  void prop(Canvas c, Offset at, int kind) {
    c.save();
    c.translate(at.dx, at.dy);
    shadow(c, const Offset(5, 15), 46, 21);
    if (kind == 0) {
      final snow = style.biome == Biome.snow;
      box(c, const Rect.fromLTWH(-5, -2, 10, 22), const Color(0xff765334), 3);
      final leaves = [
        const Offset(-12, 0),
        const Offset(12, -1),
        const Offset(0, -15),
      ];
      for (final o in leaves) {
        c.drawCircle(
          o + const Offset(0, 4),
          19,
          Paint()
            ..color = Color.lerp(style.leaves, const Color(0xff1f4037), .35)!,
        );
        c.drawCircle(
          o,
          18,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.4, -.6),
              colors: [style.leafLight, style.leaves],
            ).createShader(Rect.fromCircle(center: o, radius: 19)),
        );
        c.drawOval(
          Rect.fromCenter(center: o - const Offset(4, 7), width: 13, height: 6),
          Paint()..color = Colors.white.withValues(alpha: .18),
        );
      }
      for (final o in [
        const Offset(-17, 3),
        const Offset(12, -10),
        const Offset(1, -20),
      ]) {
        c.drawCircle(
          o,
          2.4,
          Paint()..color = snow ? Colors.white : style.accent,
        );
      }
      // Small leaf veins and fruit add detail without enlarging hiding props.
      for (final o in leaves) {
        c.drawArc(
          Rect.fromCircle(center: o, radius: 12),
          -.8,
          1.4,
          false,
          Paint()
            ..color = style.leafLight.withValues(alpha: .4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        if (style.biome == Biome.orchard) {
          c.drawCircle(
            o + const Offset(6, 4),
            4,
            Paint()..color = const Color(0xffc85e43),
          );
          c.drawCircle(
            o + const Offset(5, 3),
            1.2,
            Paint()..color = const Color(0xffffc58a),
          );
        }
        if (snow) {
          c.drawArc(
            Rect.fromCircle(center: o - const Offset(0, 4), radius: 16),
            pi,
            pi,
            true,
            Paint()..color = const Color(0xfff3f8eb),
          );
        }
      }
    } else if (kind == 1) {
      box(c, const Rect.fromLTWH(-20, -19, 40, 44), const Color(0xff755137), 4);
      box(c, const Rect.fromLTWH(-20, -21, 40, 39), const Color(0xffddb574), 4);
      box(c, const Rect.fromLTWH(-15, -16, 30, 29), const Color(0xffb98650), 2);
      for (final x in [-7.0, 3.0]) {
        c.drawLine(
          Offset(x, -15),
          Offset(x, 13),
          Paint()
            ..color = const Color(0xff92633d)
            ..strokeWidth = 1.5,
        );
      }
      final brace = Paint()
        ..color = const Color(0xffedc78b)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.square;
      c.drawLine(const Offset(-14, -15), const Offset(14, 12), brace);
      c.drawLine(const Offset(14, -15), const Offset(-14, 12), brace);
      for (final x in [-15.0, 15.0]) {
        for (final y in [-16.0, 13.0]) {
          c.drawCircle(
            Offset(x, y),
            1.6,
            Paint()..color = const Color(0xff775a3f),
          );
        }
      }
      box(c, const Rect.fromLTWH(-18, -21, 36, 3), const Color(0xffffd999), 2);
      if (style.biome == Biome.harbor) {
        box(c, const Rect.fromLTWH(-7, -7, 14, 12), const Color(0xffdbe6d1), 2);
        c.drawPath(
          Path()
            ..moveTo(-5, -1)
            ..quadraticBezierTo(0, -6, 5, -1)
            ..quadraticBezierTo(0, 4, -5, -1)
            ..close(),
          Paint()..color = style.leaves,
        );
      }
    } else {
      box(
        c,
        const Rect.fromLTWH(-17, -19, 34, 43),
        const Color(0xff795034),
        12,
      );
      final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-17, -22, 34, 41),
        const Radius.circular(11),
      );
      c.drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xffa16e43), Color(0xffe0b978), Color(0xffa16e43)],
          ).createShader(body.outerRect),
      );
      for (final x in [-9.0, 0.0, 9.0]) {
        c.drawLine(
          Offset(x, -16),
          Offset(x, 17),
          Paint()
            ..color = const Color(0x55805c3c)
            ..strokeWidth = 1,
        );
      }
      for (final y in [-12.0, 9.0]) {
        box(c, Rect.fromLTWH(-17, y, 34, 5), const Color(0xff546d65), 2);
        box(c, Rect.fromLTWH(-14, y, 27, 1.5), const Color(0xffadbbb0), 1);
      }
      c.drawOval(
        const Rect.fromLTWH(-15, -24, 30, 10),
        Paint()..color = const Color(0xfff0cd8f),
      );
      c.drawOval(
        const Rect.fromLTWH(-11, -22, 22, 6),
        Paint()..color = const Color(0xffc59a62),
      );
      c.drawCircle(
        const Offset(4, -19),
        2,
        Paint()..color = const Color(0xff976d42),
      );
    }
    if (style.biome == Biome.snow && kind != 0) {
      box(c, const Rect.fromLTWH(-17, -24, 34, 5), const Color(0xffeff8ec), 3);
    }
    c.restore();
  }

  void character(
    Canvas c,
    Offset at,
    bool hunter, {
    double scale = 1,
    double stride = 0,
    double facing = 0,
    bool moving = false,
  }) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(scale);
    shadow(c, const Offset(2, 19), 34, 13);
    final step = moving ? sin(stride) * 3 : 0.0;
    final coat = hunter ? const Color(0xffd77b4b) : const Color(0xff498e9b);
    final dark = hunter ? const Color(0xff79432f) : const Color(0xff285864);
    // Boots, backpack, coat and soft arm highlights.
    box(c, Rect.fromLTWH(-11, 12 + step, 9, 10), const Color(0xff34433e), 4);
    box(c, Rect.fromLTWH(3, 12 - step, 9, 10), const Color(0xff34433e), 4);
    c.translate(0, moving ? -step.abs() * .4 : sin(animationTime * 2) * .35);
    box(c, const Rect.fromLTWH(-17, -3, 34, 19), dark, 7);
    final torso = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -6, 25, 24),
      const Radius.circular(8),
    );
    c.drawRRect(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(coat, Colors.white, .23)!, coat, dark],
        ).createShader(torso.outerRect),
    );
    box(
      c,
      const Rect.fromLTWH(-9, -3, 5, 13),
      Color.lerp(coat, Colors.white, .2)!,
      3,
    );
    box(c, const Rect.fromLTWH(-14, 12, 28, 4), dark, 2);
    // Scarf trails to one side, giving each role a distinct silhouette.
    final scarf = hunter ? const Color(0xffffd56c) : const Color(0xffbde78b);
    final tail = Path()
      ..moveTo(7, -3)
      ..lineTo(23, 3 + sin(animationTime * 6) * 2)
      ..lineTo(17, 9 + sin(animationTime * 6) * 2)
      ..lineTo(5, 1)
      ..close();
    c.drawPath(tail, Paint()..color = scarf);
    c.drawCircle(
      const Offset(0, -12),
      12,
      Paint()..color = const Color(0xff9b6749),
    );
    c.drawCircle(
      const Offset(0, -14),
      11,
      Paint()..color = const Color(0xfff4d5a2),
    );
    c.drawCircle(
      Offset(-4 + facing * 2, -14),
      1.6,
      Paint()..color = const Color(0xff39453d),
    );
    c.drawCircle(
      Offset(4 + facing * 2, -14),
      1.6,
      Paint()..color = const Color(0xff39453d),
    );
    box(c, const Rect.fromLTWH(-10, -5, 20, 5), scarf, 2);
    c.drawOval(
      const Rect.fromLTWH(-9, -11, 4, 2),
      Paint()..color = const Color(0x66cf8b69),
    );
    c.drawOval(
      const Rect.fromLTWH(5, -11, 4, 2),
      Paint()..color = const Color(0x66cf8b69),
    );
    box(c, const Rect.fromLTWH(-1, 2, 2, 10), dark.withValues(alpha: .55), 1);
    c.drawCircle(const Offset(2, 7), 1.3, Paint()..color = scarf);
    if (hunter) {
      box(c, const Rect.fromLTWH(-10, -30, 20, 12), const Color(0xff795538), 5);
      box(c, const Rect.fromLTWH(-15, -22, 30, 5), const Color(0xffb88b50), 3);
      box(c, const Rect.fromLTWH(-9, -25, 18, 3), const Color(0xffe4c17c), 1);
      c.drawCircle(
        const Offset(15, 6),
        5,
        Paint()..color = const Color(0xfff3dba1),
      );
      c.drawCircle(
        const Offset(15, 6),
        3,
        Paint()..color = const Color(0xff799fa1),
      );
    } else {
      c.drawArc(
        const Rect.fromLTWH(-13, -30, 26, 23),
        pi,
        pi,
        true,
        Paint()..color = dark,
      );
      box(c, const Rect.fromLTWH(-13, -21, 26, 5), const Color(0xff68b7af), 3);
      c.drawCircle(const Offset(5, -29), 4, Paint()..color = scarf);
    }
    c.restore();
  }

  void terrain(Canvas c) => ArenaScenery(match.arena, style).paint(c);

  void render(
    Canvas c,
    Vector2 size, {
    bool preview = false,
    bool cacheScenery = false,
  }) {
    final scale = min(size.x / 960, size.y / 720);
    if (scale <= 0) return;
    c.save();
    c.translate((size.x - 960 * scale) / 2, (size.y - 720 * scale) / 2);
    c.scale(scale);
    if (cacheScenery) {
      if (_ground == null) {
        final recorder = PictureRecorder();
        terrain(Canvas(recorder));
        _ground = recorder.endRecording();
      }
      c.drawPicture(_ground!);
    } else {
      terrain(c);
    }
    if (!preview && match.captureEffect > 0) {
      final progress = 1 - match.captureEffect / Match.captureEffectDuration;
      final color = match.captureHit
          ? const Color(0xffd4ff88)
          : const Color(0xffffbf7b);
      c.drawCircle(
        match.captureOrigin,
        Match.captureRadius,
        Paint()..color = color.withValues(alpha: .2 * (1 - progress)),
      );
      for (final radius in [
        Match.captureRadius,
        Match.captureRadius * progress,
      ]) {
        c.drawCircle(
          match.captureOrigin,
          radius,
          Paint()
            ..color = color.withValues(alpha: 1 - progress)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5,
        );
      }
      for (var i = 0; i < 12; i++) {
        final a = i * pi / 6;
        final at =
            match.captureOrigin +
            Offset(cos(a), sin(a)) * Match.captureRadius * progress;
        c.drawCircle(at, 2.5 * (1 - progress), Paint()..color = color);
      }
      label(
        c,
        match.captureHit ? 'CAUGHT!' : 'NO REBEL IN RANGE',
        match.captureOrigin - const Offset(0, 85),
      );
    }
    if (!preview) {
      if (_senseRemaining > 0 && !match.hiding) {
        final radius = 210 * (1 - _senseRemaining);
        c.drawCircle(
          _senseOrigin,
          radius,
          Paint()
            ..color = const Color(
              0xff9ae4df,
            ).withValues(alpha: _senseRemaining * .75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        c.drawCircle(
          _senseOrigin,
          radius,
          Paint()
            ..color = const Color(
              0xff9ae4df,
            ).withValues(alpha: _senseRemaining * .035),
        );
      }
      final target = match.hidingPlace(match.human);
      if (target != null) {
        final targetRect = Rect.fromCircle(
          center: target.at,
          radius: 31 + sin(animationTime * 4) * 2,
        );
        for (var n = 0; n < 4; n++) {
          c.drawArc(
            targetRect,
            animationTime * .4 + n * pi / 2,
            pi / 3,
            false,
            Paint()
              ..color = const Color(0xffffe8a6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }
    }
    final objects = <({double y, int index, bool pawn})>[
      for (var i = 0; i < match.props.length; i++)
        (y: match.props[i].at.dy + 18, index: i, pawn: false),
      for (var i = 0; i < match.players.length; i++)
        if (!match.players[i].caught && match.visible(i))
          (y: match.players[i].at.dy + 20, index: i, pawn: true),
    ]..sort((a, b) => a.y.compareTo(b.y));
    for (final object in objects) {
      if (!object.pawn) {
        final p = match.props[object.index];
        final obscuresPlayer = match.players.asMap().entries.any((entry) {
          final player = entry.value;
          return !player.caught &&
              player.hidingIn == null &&
              match.visible(entry.key) &&
              (player.at.dx - p.at.dx).abs() < 32 &&
              player.at.dy < p.at.dy - 2 &&
              player.at.dy > p.at.dy - 45;
        });
        if (obscuresPlayer)
          c.saveLayer(
            Rect.fromCircle(center: p.at, radius: 50),
            Paint()..color = Colors.white.withValues(alpha: .5),
          );
        prop(c, p.at, p.kind);
        if (obscuresPlayer) c.restore();
        continue;
      }
      final i = object.index;
      final p = match.players[i];
      if (p.caught || !match.visible(i)) continue;
      if (p.hidingIn != null) {
        if (!preview) {
          c.drawCircle(
            p.at,
            29,
            Paint()
              ..color = const Color(0xffe2ff96)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
          label(
            c,
            i == match.human ? 'YOU · HIDDEN' : 'ALLY · HIDDEN',
            p.at - const Offset(0, 53),
          );
        }
        continue;
      }
      if (i == match.human && !preview) {
        c.drawOval(
          Rect.fromCenter(
            center: p.at + const Offset(0, 17),
            width: 42,
            height: 20,
          ),
          Paint()
            ..color = const Color(0xffedffbc)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      if (p.vanish > 0) {
        c.saveLayer(
          Rect.fromCircle(center: p.at, radius: 40),
          Paint()..color = Colors.white.withValues(alpha: .4),
        );
      }
      character(
        c,
        p.at,
        p.hunter,
        stride: _stride[i] ?? 0,
        facing: _facing[i] ?? 0,
        moving: _moving[i] ?? false,
      );
      if (p.vanish > 0) c.restore();
      if (p.vanish > 0 && !preview) {
        for (var n = 0; n < 3; n++) {
          final a = animationTime * 2 + n * pi * 2 / 3;
          final at = p.at + Offset(cos(a) * 25, sin(a) * 12 + 8);
          c.drawCircle(at, 2.5, Paint()..color = const Color(0xffc3f7ec));
        }
      }
      if (!preview) {
        if (i == match.human) {
          label(
            c,
            p.vanish > 0 ? 'VANISH ${p.vanish.toStringAsFixed(1)}s' : 'YOU',
            p.at - const Offset(0, 54),
          );
        } else if (match.human != 0) {
          label(c, p.hunter ? 'HUNTER' : 'REBEL', p.at - const Offset(0, 54));
        }
      }
    }
    if (!preview) {
      for (final burst in _bursts) {
        if (!match.visible(burst.owner) || match.players[burst.owner].caught)
          continue;
        final progress = 1 - burst.remaining / .55;
        c.drawCircle(
          burst.at,
          18 + progress * 25,
          Paint()
            ..color = burst.color.withValues(alpha: (1 - progress) * .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        for (var n = 0; n < 6; n++) {
          final angle = n * pi / 3;
          final at =
              burst.at + Offset(cos(angle), sin(angle)) * (15 + progress * 28);
          c.drawCircle(
            at,
            2 * (1 - progress),
            Paint()..color = burst.color.withValues(alpha: 1 - progress),
          );
        }
      }
    }
    atmosphere(c, preview: preview);
    if (!preview && match.hiding && match.human == 0) {
      box(c, const Rect.fromLTWH(0, 0, 960, 720), const Color(0xff203b34));
      for (var i = 0; i < 3; i++) {
        c.drawCircle(
          const Offset(480, 330),
          55 + i * 35.0,
          Paint()
            ..color = const Color(0xffd4ed9b).withValues(alpha: .12 - i * .03)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      label(c, 'LET THEM HIDE', const Offset(480, 315));
      label(
        c,
        'The hunt begins in ${match.time.ceil()}s',
        const Offset(480, 350),
      );
    }
    c.restore();
  }

  void atmosphere(Canvas c, {bool preview = false}) {
    const bounds = Rect.fromLTWH(0, 0, 960, 720);
    // Soft lighting stays subtle enough to preserve player contrast.
    c.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.45, -.65),
          radius: 1.3,
          colors: [Color(0x16fff4c6), Color(0x00ffffff), Color(0x28203e39)],
          stops: [0, .45, 1],
        ).createShader(bounds),
    );
    if (preview) return;
    c.save();
    c.clipRect(bounds);
    for (var i = 0; i < 24; i++) {
      final snow = style.biome == Biome.snow;
      final x = (i * 137 + animationTime * (snow ? 9 : 5)) % 960;
      final y = (i * 97 + animationTime * (snow ? 17 : -4)) % 720;
      final alpha = .18 + (sin(animationTime * 1.3 + i) + 1) * .12;
      if (snow) {
        c.drawCircle(
          Offset(x, y),
          1.2 + i % 3 * .4,
          Paint()..color = Colors.white.withValues(alpha: alpha + .2),
        );
      } else if (style.biome == Biome.orchard || style.biome == Biome.ruins) {
        c.save();
        c.translate(x, y);
        c.rotate(animationTime * .4 + i);
        c.drawOval(
          const Rect.fromLTWH(-2, -1, 4, 2),
          Paint()..color = style.accent.withValues(alpha: alpha),
        );
        c.restore();
      } else {
        c.drawCircle(
          Offset(x, y),
          1.3,
          Paint()..color = const Color(0xffffefb0).withValues(alpha: alpha),
        );
      }
    }
    c.restore();
  }
}

class _InteractionBurst {
  final int owner;
  final Offset at;
  final Color color;
  double remaining = .55;
  _InteractionBurst(this.owner, this.at, this.color);
}
