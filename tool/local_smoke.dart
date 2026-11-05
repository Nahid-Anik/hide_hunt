// Run against a room on a real phone: dart run tool/local_smoke.dart HOST CODE
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/local_smoke.dart HOST CODE [PORT]');
    exitCode = 64;
    return;
  }
  final socket = await WebSocket.connect(
    Uri(
      scheme: 'ws',
      host: args[0],
      port: args.length > 2 ? int.parse(args[2]) : 45873,
      path: '/join',
      queryParameters: {'code': args[1], 'v': '2'},
    ).toString(),
  ).timeout(const Duration(seconds: 10));
  Map<String, dynamic>? state;
  int seat = -1, snapshots = 0;
  String? failure;
  socket.listen(
    (raw) {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      if (m['type'] == 'welcome') {
        seat = m['seat'] as int;
        stdout.writeln('Joined seat $seat. Start the match on the host.');
      }
      if (m['type'] == 'state') {
        state = m['match'] as Map<String, dynamic>;
        snapshots++;
      }
      if (m['type'] == 'error') failure = m['message'] as String;
    },
    onError: (Object e) => failure = e.toString(),
    onDone: () => failure ??= 'Connection closed',
  );
  var x = 0.0;
  final heartbeat = Timer.periodic(const Duration(milliseconds: 100), (_) {
    if (socket.readyState == WebSocket.open)
      socket.add(jsonEncode({'type': 'input', 'x': x, 'y': 0}));
  });
  Future<void> until(bool Function() condition, {int seconds = 10}) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (!condition()) {
      if (failure != null) throw StateError(failure!);
      if (DateTime.now().isAfter(deadline))
        throw TimeoutException('State did not arrive');
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  try {
    await until(() => seat > 0 && state != null, seconds: 60);
    final initialX = (state!['players'][seat]['at'][0] as num).toDouble();
    x = 1;
    await until(() => (state!['players'][seat]['at'][0] as num) > initialX + 8);
    x = 0;
    stdout.writeln('PASS: remote movement is reflected by the phone host.');
    socket.add(jsonEncode({'type': 'action', 'kind': 'secondary'}));
    await until(() => (state!['players'][seat]['vanish'] as num) > 0);
    stdout.writeln('PASS: host activated remote Vanish.');
    await until(() => (state!['players'][seat]['vanish'] as num) == 0);
    if (snapshots < 20) throw StateError('Too few snapshots: $snapshots');
    stdout.writeln(
      'PASS: Vanish expired; received $snapshots authoritative snapshots.',
    );
  } finally {
    heartbeat.cancel();
    await socket.close();
  }
}
