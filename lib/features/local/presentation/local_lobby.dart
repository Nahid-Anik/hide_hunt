import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../hunt/data/arenas.dart';
import '../../hunt/presentation/play_screen.dart';
import '../data/local_session.dart';
import '../data/network_route.dart';

class LocalLobby extends StatefulWidget {
  final int arenaIndex;
  const LocalLobby({super.key, required this.arenaIndex});
  @override
  State<LocalLobby> createState() => _LocalLobbyState();
}

class _LocalLobbyState extends State<LocalLobby> {
  final address = TextEditingController(), code = TextEditingController();
  LocalSession? session;
  bool busy = false, playing = false;
  String error = '';
  late int selectedMap = widget.arenaIndex;

  @override
  void dispose() {
    session?.removeListener(changed);
    session?.dispose();
    unawaited(NetworkRoute.release());
    address.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> connect(bool host) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (host) {
        await NetworkRoute.release();
      } else {
        await NetworkRoute.useWifi();
      }
      await NetworkRoute.keepAwake();
      final next = host
          ? await LocalSession.host(selectedMap)
          : await LocalSession.join(address.text, code.text);
      if (!mounted) {
        next.dispose();
        await NetworkRoute.release();
        return;
      }
      session = next..addListener(changed);
      changed();
    } catch (e) {
      await NetworkRoute.release();
      if (!mounted) return;
      setState(
        () => error = e is FormatException
            ? e.message.toString()
            : e is StateError
            ? e.message
            : e is TimeoutException
            ? 'Could not reach the host. Check the address and connect both phones to the same Wi-Fi or hotspot.'
            : e is SocketException
            ? 'Could not connect. Check Wi-Fi, the host address, and that the room is open. To host, close any other open room first.'
            : 'Could not open the room. Connect to the same Wi-Fi or hotspot and try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void changed() {
    if (!mounted || playing) return;
    setState(() {});
    final s = session;
    if (s != null && s.started && s.error.isEmpty) {
      playing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                Play(arena: s.match!.arena, human: s.seat, session: s),
          ),
        );
        if (!mounted) return;
        leave();
      });
    }
  }

  void leave() {
    session?.removeListener(changed);
    session?.dispose();
    unawaited(NetworkRoute.release());
    setState(() {
      session = null;
      playing = false;
      error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Scaffold(
      appBar: AppBar(title: const Text('Local play')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.wifi_tethering_rounded,
                    size: 52,
                    color: Color(0xff345e43),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s == null ? 'Same room. Same hunt.' : 'Your room is open',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Connect every phone to the same Wi-Fi, or turn on a phone’s hotspot in Android Settings and connect the others to it. No internet needed. Keep the host app open.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (s == null) ...[
                    DropdownButtonFormField<int>(
                      initialValue: selectedMap,
                      decoration: const InputDecoration(
                        labelText: 'Host map',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var i = 0; i < arenas.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(arenas[i].name),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => selectedMap = value!),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy ? null : () => connect(true),
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text('Host on ${arenas[selectedMap].name}'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Host = hunter. Guests = rebels. 2–4 phones; bots fill empty seats.',
                      textAlign: TextAlign.center,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(),
                    ),
                    const Text(
                      'Join a friend',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: address,
                      enabled: !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Host address',
                        hintText: '192.168.43.1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: code,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '6-digit room code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => connect(false),
                      icon: const Icon(Icons.login),
                      label: const Text('Join room'),
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ] else ...[
                    if (s.isHost)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SHARE WITH YOUR FRIENDS'),
                              const SizedBox(height: 10),
                              SelectableText(
                                s.code,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text('Host address'),
                              for (final ip in s.addresses)
                                SelectableText(
                                  ip,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              if (s.addresses.isEmpty)
                                const Text(
                                  'No network address found. Enable Wi-Fi or hotspot, then recreate the room.',
                                ),
                              if (s.addresses.length > 1)
                                const Text(
                                  'Use the address for your Wi-Fi or hotspot connection.',
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      '${s.members.length}/4 phones connected',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    for (var i = 0; i < 4; i++)
                      ListTile(
                        leading: Icon(
                          s.members.containsKey(i)
                              ? Icons.phone_android
                              : Icons.smart_toy_outlined,
                        ),
                        title: Text(s.members[i] ?? 'Bot · Rebel'),
                        trailing: i == s.seat ? const Text('YOU') : null,
                      ),
                    const SizedBox(height: 16),
                    if (s.isHost)
                      FilledButton(
                        onPressed: s.members.length < 2 || s.error.isNotEmpty
                            ? null
                            : s.startMatch,
                        child: Text(
                          s.members.length < 2
                              ? 'Waiting for a friend…'
                              : 'Start match',
                        ),
                      )
                    else
                      const Text(
                        'Waiting for the host to start…',
                        textAlign: TextAlign.center,
                      ),
                    TextButton(
                      onPressed: leave,
                      child: Text(s.isHost ? 'Close room' : 'Leave room'),
                    ),
                  ],
                  if (error.isNotEmpty || (s?.error.isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        s?.error.isNotEmpty == true ? s!.error : error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'If joining fails, check the room code and address. Some guest Wi-Fi networks isolate devices; use a phone hotspot instead. Turn off VPNs if they block local connections.',
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
