import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../hunt/data/arenas.dart';
import '../hunt/domain/match.dart';
import '../hunt/game/arena_renderer.dart';
import '../hunt/presentation/play_screen.dart';
import '../local/presentation/local_lobby.dart';
import 'interactive_graphics.dart';

const _ink = Color(0xff193d34);
const _cream = Color(0xfffff0cb);
const _gold = Color(0xffffd37b);

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _ForestBackdrop()),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 650;
              final logo = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(
                          text: 'HIDE',
                          style: TextStyle(color: Color(0xffdcf4af)),
                        ),
                        TextSpan(
                          text: '\n& HUNT',
                          style: TextStyle(color: _gold),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: wide ? 60 : 68,
                      height: .92,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.5,
                      shadows: const [
                        Shadow(color: Color(0xff102b26), offset: Offset(0, 5)),
                        Shadow(
                          color: Color(0x55102319),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'THE GREAT LITTLE CHASE',
                    style: TextStyle(
                      color: _cream,
                      fontSize: 10,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(
                    height: wide ? 126 : 190,
                    width: 380,
                    child: ReactiveIllustration(
                      child: CustomPaint(painter: _MenuScene()),
                    ),
                  ),
                ],
              );
              final buttons = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 310),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MenuButton(
                      label: 'PLAY SOLO',
                      icon: Icons.play_arrow_rounded,
                      primary: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const SoloSetup(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MenuButton(
                      label: 'LOCAL PLAY',
                      icon: Icons.groups_rounded,
                      onTap: () {
                        if (kIsWeb) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Local multiplayer is available in the Android app. Choose Play Solo to play in your browser.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const LocalLobby(arenaIndex: 0),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _MenuButton(
                      label: 'HOW TO PLAY',
                      icon: Icons.help_outline_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const HowToPlay(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: wide
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: logo),
                              const SizedBox(width: 40),
                              Expanded(child: buttons),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [logo, buttons],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
  @override
  Widget build(BuildContext context) => ReactiveSurface(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primary ? const Color(0xffaa773b) : const Color(0xff0e2b25),
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 57,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: primary ? _gold : const Color(0xff31594b),
            foregroundColor: primary ? const Color(0xff543d25) : _cream,
            side: BorderSide(
              color: primary
                  ? const Color(0xffffe7aa)
                  : const Color(0xff6c8b64),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: Icon(icon, size: 25),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    ),
  );
}

class SoloSetup extends StatefulWidget {
  const SoloSetup({super.key});
  @override
  State<SoloSetup> createState() => _SoloSetupState();
}

class _SoloSetupState extends State<SoloSetup> {
  int selected = 0, role = 1;
  Match preview = Match(arenas.first, 1, 42);
  void changeMap(int delta) => setState(() {
    selected = (selected + delta) % arenas.length;
    preview = Match(arenas[selected], 1, 42);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    appBar: AppBar(
      title: const Text('Solo game'),
      backgroundColor: _ink,
      foregroundColor: _cream,
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedSwitcher(
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 260,
                    ),
                    child: InteractiveArenaPreview(
                      key: ValueKey(selected),
                      match: preview,
                      onPrevious: () => changeMap(-1),
                      onNext: () => changeMap(1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => changeMap(-1),
                      tooltip: 'Previous map',
                      icon: const Icon(Icons.chevron_left, color: _gold),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            arenas[selected].name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _cream,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${selected + 1} / ${arenas.length}',
                            style: const TextStyle(
                              color: Color(0xffa4b99a),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => changeMap(1),
                      tooltip: 'Next map',
                      icon: const Icon(Icons.chevron_right, color: _gold),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    for (final value in [1, 0])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: value == 1 ? 6 : 0,
                            left: value == 0 ? 6 : 0,
                          ),
                          child: Semantics(
                            selected: role == value,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                foregroundColor: role == value ? _ink : _cream,
                                backgroundColor: role == value
                                    ? const Color(0xffd6eda6)
                                    : const Color(0xff294d41),
                                side: BorderSide(
                                  color: role == value
                                      ? const Color(0xffe9f8c6)
                                      : const Color(0xff668367),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => setState(() => role = value),
                              child: Column(
                                children: [
                                  Icon(
                                    value == 0
                                        ? Icons.radar
                                        : Icons.visibility_off_outlined,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    value == 0 ? 'Hunter' : 'Rebel',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'LET’S PLAY',
                  icon: Icons.play_arrow_rounded,
                  primary: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          Play(arena: arenas[selected], human: role),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HowToPlay extends StatelessWidget {
  const HowToPlay({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    appBar: AppBar(
      title: const Text('How to play'),
      backgroundColor: _ink,
      foregroundColor: _cream,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            _GuideCard(
              Icons.timer_outlined,
              'The chase',
              '20 seconds to hide. 3 minutes to hunt. Catch all three rebels to win immediately, or two before time runs out.',
            ),
            _GuideCard(
              Icons.visibility_off_outlined,
              'Be a rebel',
              'Move near an object and tap Hide to get inside. Move or tap Leave to come out. Vanish makes you invisible for 3 seconds so you can escape and hide again. It recharges in 20 seconds; you can still be captured while invisible.',
            ),
            _GuideCard(
              Icons.radar_rounded,
              'Be a hunter',
              'Get close and tap Capture. The circle shows your reach. Sense tells you if a rebel is nearby, except during Vanish. Walls block sight and capture.',
            ),
            _GuideCard(
              Icons.sports_esports_outlined,
              'The controls',
              'Move with the joystick and tap the action buttons. On a keyboard: WASD or arrows to move, E to Capture / Hide, Q to Sense / Vanish.',
            ),
            _GuideCard(
              Icons.wifi_tethering,
              'Play with friends',
              'Connect 2–4 phones to the same Wi-Fi or phone hotspot. Open Local Play. One player hosts; the others join with the address and room code. The host is the hunter. Bots fill spare seats.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final String title, description;
  const _GuideCard(this.icon, this.title, this.description);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xff294c40),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _cream,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(color: Color(0xffd1dfc6), height: 1.6),
        ),
      ],
    ),
  );
}

class _MenuScene extends CustomPainter {
  final renderer = ArenaRenderer(Match(arenas.first, 1, 42));
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * .58);
    final scale = min(size.width / 370, size.height / 165);
    canvas.scale(scale);
    canvas.drawOval(
      const Rect.fromLTWH(-170, -12, 340, 83),
      Paint()..color = const Color(0x40102621),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-166, -23, 332, 78),
      Paint()..color = const Color(0xff4e7450),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-166, -29, 332, 73),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xffaec67b), Color(0xff769951)],
        ).createShader(const Rect.fromLTWH(-166, -29, 332, 73)),
    );
    for (final point in [
      const Offset(-125, -24),
      const Offset(124, -30),
      const Offset(-91, -49),
    ]) {
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.scale(1.45);
      renderer.prop(canvas, Offset.zero, 0);
      canvas.restore();
    }
    renderer.prop(canvas, const Offset(-105, 20), 1);
    renderer.character(canvas, const Offset(-37, 6), true, scale: 2.3);
    renderer.character(canvas, const Offset(62, -6), false, scale: 2.1);
    canvas.save();
    canvas.translate(76, 24);
    canvas.scale(1.65);
    renderer.prop(canvas, Offset.zero, 2);
    canvas.restore();
    for (var i = 0; i < 7; i++) {
      canvas.drawCircle(
        Offset(-150 + i * 47.0, -75 - (i % 3) * 12),
        i.isEven ? 2 : 1.3,
        Paint()..color = const Color(0xfff2db88).withValues(alpha: .7),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MenuScene oldDelegate) => false;
}

class _ForestBackdrop extends CustomPainter {
  const _ForestBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.4),
          radius: 1.1,
          colors: [Color(0xff527452), Color(0xff1d4036), Color(0xff102e2a)],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 16; i++) {
      final side = i.isEven ? -1 : 1;
      final x = side < 0 ? -15.0 : size.width + 15;
      final y = size.height * i / 15;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + side * 8, y),
          width: 130 + (i % 3) * 35,
          height: 160,
        ),
        Paint()
          ..color = i.isEven
              ? const Color(0x70487345)
              : const Color(0x70466a40),
      );
    }
    for (var i = 0; i < 28; i++) {
      final x = (i * 127 % 997) / 997 * size.width;
      final y = (i * 173 % 877) / 877 * size.height;
      canvas.drawCircle(
        Offset(x, y),
        i % 3 == 0 ? 2 : 1,
        Paint()..color = const Color(0x558ddd91),
      );
    }
  }

  @override
  bool shouldRepaint(_ForestBackdrop oldDelegate) => false;
}
