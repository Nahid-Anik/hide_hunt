import 'dart:math';
import 'package:flame/extensions.dart' show Vector2;
import 'package:flutter/material.dart';
import '../hunt/domain/match.dart';
import '../hunt/domain/models/prop.dart';
import '../hunt/game/arena_renderer.dart';

/// Adds tactile feedback without taking ownership of the child's actions.
class ReactiveSurface extends StatefulWidget {
  final Widget child;
  const ReactiveSurface({super.key, required this.child});
  @override
  State<ReactiveSurface> createState() => _ReactiveSurfaceState();
}

class _ReactiveSurfaceState extends State<ReactiveSurface> {
  bool hovered = false, pressed = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() {
        hovered = false;
        pressed = false;
      }),
      child: Focus(
        onFocusChange: (value) => setState(() => focused = value),
        canRequestFocus: false,
        child: Listener(
          onPointerDown: (_) => setState(() => pressed = true),
          onPointerUp: (_) => setState(() => pressed = false),
          onPointerCancel: (_) => setState(() => pressed = false),
          child: AnimatedScale(
            duration: Duration(milliseconds: reduced ? 0 : 120),
            curve: Curves.easeOutCubic,
            scale: reduced
                ? 1
                : pressed
                ? .97
                : hovered || focused
                ? 1.025
                : 1,
            child: AnimatedContainer(
              duration: Duration(milliseconds: reduced ? 0 : 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xffffdc8d,
                    ).withValues(alpha: hovered || focused ? .2 : 0),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class ReactiveIllustration extends StatefulWidget {
  final Widget child;
  const ReactiveIllustration({super.key, required this.child});
  @override
  State<ReactiveIllustration> createState() => _ReactiveIllustrationState();
}

class _ReactiveIllustrationState extends State<ReactiveIllustration>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  Offset aim = Offset.zero;
  void point(Offset local, Size size) => setState(
    () => aim = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1, 1),
      (local.dy / size.height * 2 - 1).clamp(-1, 1),
    ),
  );
  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Interactive game illustration',
      child: LayoutBuilder(
        builder: (context, bounds) => MouseRegion(
          onHover: (e) => point(e.localPosition, bounds.biggest),
          onExit: (_) => setState(() => aim = Offset.zero),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!reduced) pulse.forward(from: 0);
            },
            child: Listener(
              onPointerMove: (e) => point(e.localPosition, bounds.biggest),
              onPointerUp: (_) => setState(() => aim = Offset.zero),
              onPointerCancel: (_) => setState(() => aim = Offset.zero),
              child: TweenAnimationBuilder<Offset>(
                tween: Tween(end: reduced ? Offset.zero : aim),
                duration: Duration(milliseconds: reduced ? 0 : 180),
                curve: Curves.easeOut,
                builder: (context, tilt, child) => AnimatedBuilder(
                  animation: pulse,
                  child: child,
                  builder: (context, child) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .001)
                      ..rotateX(-tilt.dy * .035)
                      ..rotateY(tilt.dx * .065)
                      ..translateByDouble(
                        tilt.dx * 5,
                        tilt.dy * 3 - (reduced ? 0 : sin(pulse.value * pi) * 7),
                        0,
                        1,
                      ),
                    child: child,
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InteractiveArenaPreview extends StatefulWidget {
  final Match match;
  final VoidCallback onPrevious, onNext;
  const InteractiveArenaPreview({
    super.key,
    required this.match,
    required this.onPrevious,
    required this.onNext,
  });
  @override
  State<InteractiveArenaPreview> createState() =>
      _InteractiveArenaPreviewState();
}

class _InteractiveArenaPreviewState extends State<InteractiveArenaPreview>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final ArenaRenderer renderer = ArenaRenderer(widget.match);
  Prop? selected;
  double drag = 0;
  void inspect(Offset local, Size size) {
    final at = Offset(
      local.dx / size.width * 960,
      local.dy / size.height * 720,
    );
    Prop? near;
    var distance = 48.0;
    for (final p in widget.match.props) {
      final d = (p.at - at).distance;
      if (d < distance) {
        distance = d;
        near = p;
      }
    }
    setState(() => selected = near);
    if (MediaQuery.disableAnimationsOf(context))
      pulse.value = 1;
    else
      pulse.forward(from: 0);
  }

  @override
  void dispose() {
    pulse.dispose();
    renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 4 / 3,
    child: LayoutBuilder(
      builder: (context, bounds) => Semantics(
        label:
            'Arena preview. Tap an object to inspect it. Swipe to change maps.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) => inspect(e.localPosition, bounds.biggest),
          onHorizontalDragStart: (_) => drag = 0,
          onHorizontalDragUpdate: (e) => drag += e.delta.dx,
          onHorizontalDragEnd: (_) {
            if (drag < -40) widget.onNext();
            if (drag > 40) widget.onPrevious();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: pulse,
                builder: (context, _) => CustomPaint(
                  painter: _PreviewPainter(renderer, selected, pulse.value),
                ),
              ),
              if (selected != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: IgnorePointer(
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xee193d34),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${['Tree', 'Crate', 'Barrel'][selected!.kind]} hiding place',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xffffe1a3),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PreviewPainter extends CustomPainter {
  final ArenaRenderer renderer;
  final Prop? selected;
  final double progress;
  _PreviewPainter(this.renderer, this.selected, this.progress);
  @override
  void paint(Canvas c, Size size) {
    renderer.render(
      c,
      Vector2(size.width, size.height),
      preview: true,
      cacheScenery: true,
    );
    final prop = selected;
    if (prop == null) return;
    c.save();
    c.scale(size.width / 960);
    c.drawCircle(
      prop.at,
      30 + progress * 18,
      Paint()
        ..color = const Color(0xffffedac).withValues(alpha: 1 - progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    c.drawCircle(
      prop.at,
      30,
      Paint()
        ..color = const Color(0xffffedac)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    c.translate(prop.at.dx, prop.at.dy);
    final bounce = sin(progress * pi);
    c.translate(0, -bounce * 7);
    c.scale(1 + bounce * .1);
    renderer.prop(c, Offset.zero, prop.kind);
    c.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.selected != selected ||
      oldDelegate.progress != progress;
}
