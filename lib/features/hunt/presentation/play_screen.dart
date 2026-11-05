import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/models/arena.dart';
import '../domain/match.dart';
import '../game/hunt_game.dart';
import 'widgets/action_button.dart';
import 'widgets/joystick.dart';
import '../../local/data/local_session.dart';

class Play extends StatefulWidget {
  final Arena arena;
  final int human;
  final LocalSession? session;
  const Play({
    super.key,
    required this.arena,
    required this.human,
    this.session,
  });
  @override
  State<Play> createState() => _Play();
}

class _Play extends State<Play> with WidgetsBindingObserver {
  late HuntGame game;
  int round = 0;
  final keys = <LogicalKeyboardKey>{};
  Offset stick = Offset.zero;
  final focus = FocusNode();
  String hint = '';
  Timer? hintTimer;
  int networkRound = 0, feedbackRevision = 0;
  void networkChanged() {
    if (!mounted) return;
    final s = widget.session!;
    if (s.round != networkRound) setState(fresh);
    if (s.feedbackRevision != feedbackRevision) {
      feedbackRevision = s.feedbackRevision;
      if (s.feedback.isNotEmpty) showHint(s.feedback);
    }
    if (s.paused || s.error.isNotEmpty) {
      stick = Offset.zero;
      keys.clear();
      // Only send on a change; session notifications can be synchronous.
      if (game.movement != Offset.zero) game.movement = Offset.zero;
    }
  }

  void showHint(String message) {
    hintTimer?.cancel();
    setState(() => hint = message);
    hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => hint = '');
    });
  }

  void fresh() {
    hintTimer?.cancel();
    game = HuntGame(
      widget.session?.match ??
          Match(
            widget.arena,
            widget.human,
            DateTime.now().microsecondsSinceEpoch,
          ),
      session: widget.session,
    );
    networkRound = widget.session?.round ?? 0;
    round++;
    keys.clear();
    stick = Offset.zero;
    hint = '';
  }

  @override
  void initState() {
    super.initState();
    fresh();
    widget.session?.addListener(networkChanged);
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    hintTimer?.cancel();
    widget.session?.removeListener(networkChanged);
    widget.session?.setMovement(Offset.zero);
    WidgetsBinding.instance.removeObserver(this);
    focus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    // Android can briefly lose focus while entering fullscreen/landscape.
    // Stop input on focus loss, but only pause when the app actually hides.
    if (state != AppLifecycleState.resumed) {
      game.movement = Offset.zero;
      stick = Offset.zero;
      keys.clear();
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      pause(true);
    }
  }

  void pause(bool value) {
    setState(() {
      game.paused = value;
      game.movement = Offset.zero;
      stick = Offset.zero;
      keys.clear();
    });
    widget.session?.setPaused(value);
  }

  void input() {
    var x = stick.dx, y = stick.dy;
    if (keys.contains(LogicalKeyboardKey.keyD) ||
        keys.contains(LogicalKeyboardKey.arrowRight))
      x++;
    if (keys.contains(LogicalKeyboardKey.keyA) ||
        keys.contains(LogicalKeyboardKey.arrowLeft))
      x--;
    if (keys.contains(LogicalKeyboardKey.keyS) ||
        keys.contains(LogicalKeyboardKey.arrowDown))
      y++;
    if (keys.contains(LogicalKeyboardKey.keyW) ||
        keys.contains(LogicalKeyboardKey.arrowUp))
      y--;
    game.movement = game.paused || (widget.session?.paused ?? false)
        ? Offset.zero
        : Offset(x, y);
  }

  void primary() {
    if (game.paused) return;
    if (widget.session != null) {
      widget.session!.action('primary');
      return;
    }
    final m = game.match;
    final used = m.primary(widget.human);
    showHint(
      widget.human == 0
          ? (used
                ? (m.captureHit
                      ? 'Rebel captured!'
                      : 'Miss! Get within the capture circle.')
                : '')
          : (!used
                ? 'Move closer to an unoccupied object.'
                : m.players[widget.human].hidingIn != null
                ? 'Hidden. Move or tap Leave to come out.'
                : 'You left your hiding place.'),
    );
  }

  void secondary() {
    if (widget.session != null) {
      if (!game.paused) widget.session!.action('secondary');
      return;
    }
    if (!game.paused) showHint(game.match.secondary(widget.human));
  }

  KeyEventResult key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent)
      keys.remove(e.logicalKey);
    else
      keys.add(e.logicalKey);
    if (e is KeyDownEvent) {
      if (e.logicalKey == LogicalKeyboardKey.escape) pause(!game.paused);
      if (!game.paused) {
        if (e.logicalKey == LogicalKeyboardKey.keyE) primary();
        if (e.logicalKey == LogicalKeyboardKey.keyQ) secondary();
      }
    }
    input();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Focus(
      autofocus: true,
      focusNode: focus,
      onKeyEvent: key,
      child: ValueListenableBuilder<int>(
        valueListenable: game.updates,
        builder: (context, _, child) {
          final m = game.match, p = m.players[widget.human], s = m.time.ceil();
          final network = widget.session;
          final disconnected = network?.error.isNotEmpty ?? false;
          final hostPaused = network?.paused ?? false;
          final clock =
              '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: GameWidget<HuntGame>(key: ValueKey(round), game: game),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xee355344), Color(0xee213e34)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xff859a70)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          '$clock  •  ${m.hiding
                              ? 'HIDING'
                              : p.caught
                              ? 'CAUGHT'
                              : p.hunter
                              ? 'HUNTER'
                              : 'REBEL'}  •  ${m.captures}/3 caught',
                          style: const TextStyle(
                            color: Color(0xfffff0ce),
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xee29483b),
                          foregroundColor: const Color(0xffffe2a3),
                        ),
                        onPressed: () => pause(!game.paused),
                        icon: const Icon(Icons.pause),
                      ),
                    ],
                  ),
                ),
              ),
              if (!game.paused && !m.ended && !hostPaused && !disconnected)
                SafeArea(
                  minimum: const EdgeInsets.all(18),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Joystick(
                          key: ValueKey(round),
                          changed: (v) {
                            stick = v;
                            input();
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ActionButton(
                              label: p.hunter
                                  ? 'Capture'
                                  : p.hidingIn == null
                                  ? 'Hide'
                                  : 'Leave',
                              cooldown: p.cooldown,
                              onPressed: primary,
                              enabled: m.available(widget.human),
                            ),
                            const SizedBox(width: 12),
                            ActionButton(
                              label: p.hunter
                                  ? 'Sense'
                                  : p.vanish > 0
                                  ? 'Vanished'
                                  : 'Vanish',
                              cooldown: p.skill,
                              onPressed: secondary,
                              enabled: m.available(widget.human),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (hint.isNotEmpty && !game.paused)
                Align(
                  alignment: const Alignment(0, -.65),
                  child: IgnorePointer(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        color: Colors.white,
                        backgroundColor: Color(0xcc203c32),
                      ),
                    ),
                  ),
                ),
              if (game.paused || m.ended || hostPaused || disconnected)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                disconnected
                                    ? 'Connection ended'
                                    : m.ended
                                    ? '${m.winner} win!'
                                    : hostPaused
                                    ? 'Host paused the match'
                                    : network != null
                                    ? 'Menu · match continues'
                                    : 'Paused',
                                style: const TextStyle(fontSize: 30),
                              ),
                              const SizedBox(height: 16),
                              if (disconnected)
                                Text(
                                  network!.error,
                                  textAlign: TextAlign.center,
                                ),
                              if (!disconnected &&
                                  m.ended &&
                                  network != null &&
                                  !network.isHost)
                                const Text(
                                  'Waiting for the host to start the next round.',
                                ),
                              if (!disconnected &&
                                  (!m.ended ||
                                      network == null ||
                                      network.isHost))
                                FilledButton(
                                  onPressed:
                                      (hostPaused &&
                                              network?.isHost == false) ||
                                          (m.ended &&
                                              network != null &&
                                              network.members.length < 2)
                                      ? null
                                      : () {
                                          if (m.ended) {
                                            if (network != null) {
                                              network.startMatch();
                                            } else {
                                              setState(fresh);
                                            }
                                          } else {
                                            pause(false);
                                          }
                                          focus.requestFocus();
                                        },
                                  child: Text(
                                    m.ended ? 'Play again' : 'Resume',
                                  ),
                                ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  network == null
                                      ? 'Back to maps'
                                      : network.isHost
                                      ? 'Close room'
                                      : 'Leave match',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
