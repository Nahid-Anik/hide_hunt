import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../hunt/data/arenas.dart';
import '../../hunt/domain/match.dart';
import 'match_snapshot.dart';

/// One host owns all simulation. Peers send only movement and action requests.
class LocalSession extends ChangeNotifier {
  static const protocolVersion = 2;
  static const defaultPort = 45873;
  final bool isHost;
  final int arenaIndex;
  int seat = 0, round = 0, port = defaultPort;
  String code = '', error = '', feedback = '';
  int feedbackRevision = 0;
  List<String> addresses = [];
  Map<int, String> members = {0: 'Host · Hunter'};
  Match? match;
  bool paused = false;
  bool get started => match != null;
  bool _closed = false;
  HttpServer? _server;
  WebSocket? _socket;
  Timer? _ticker, _sender;
  final _peers = <int, WebSocket>{};
  final _reserved = <int>{};
  final _inputs = <int, Offset>{0: Offset.zero};
  final _lastInput = <int, DateTime>{};
  final _lastAction = <int, DateTime>{};
  final _welcome = Completer<void>();
  Offset _movement = Offset.zero;
  LocalSession._(this.isHost, this.arenaIndex);

  static Future<LocalSession> host(
    int arenaIndex, {
    int port = defaultPort,
    InternetAddress? bindAddress,
  }) async {
    final s = LocalSession._(true, arenaIndex);
    try {
      s.code = (100000 + Random.secure().nextInt(900000)).toString();
      s._server = await HttpServer.bind(
        bindAddress ?? InternetAddress.anyIPv4,
        port,
      );
      s.port = s._server!.port;
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      s.addresses = interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .where((a) => !a.startsWith('127.'))
          .toSet()
          .toList();
      s._server!.listen(
        s._accept,
        onError: (_) =>
            s._fail('The room could not stay open. Create a new room.'),
      );
      var frame = 0;
      s._ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (s._closed || s.match == null) return;
        final now = DateTime.now();
        for (final id in s._peers.keys) {
          if (now.difference(s._lastInput[id] ?? now).inMilliseconds > 600) {
            s._inputs[id] = Offset.zero;
          }
        }
        if (!s.paused)
          s.match!.tick(.033, Offset.zero, controlledInputs: s._inputs);
        // 15 snapshots/sec; local rendering remains at the display refresh rate.
        if (++frame % 2 == 0) s._broadcast(s._state());
        s.notifyListeners();
      });
      return s;
    } catch (_) {
      s.dispose();
      rethrow;
    }
  }

  static Future<LocalSession> join(
    String address,
    String code, {
    int port = defaultPort,
  }) async {
    final ip = InternetAddress.tryParse(address.trim());
    if (ip == null || ip.type != InternetAddressType.IPv4) {
      throw const FormatException(
        'Enter the IPv4 address shown on the host phone.',
      );
    }
    final s = LocalSession._(false, 0)..code = code.trim();
    try {
      final pending = WebSocket.connect(
        Uri(
          scheme: 'ws',
          host: ip.address,
          port: port,
          path: '/join',
          queryParameters: {'code': s.code, 'v': '$protocolVersion'},
        ).toString(),
      );
      // Close a late connection if the timeout has already disposed this session.
      pending.then((socket) {
        if (s._closed) socket.close();
      }, onError: (Object _) {});
      s._socket = await pending.timeout(const Duration(seconds: 8));
      s._socket!.pingInterval = const Duration(seconds: 3);
      s._socket!.listen(
        s._receive,
        onDone: () {
          s._fail(
            'Disconnected from the host. Return to Local play and join a new room.',
          );
        },
        onError: (_) =>
            s._fail('Connection lost. Check Wi-Fi and join a new room.'),
      );
      await s._welcome.future.timeout(const Duration(seconds: 5));
      if (s.error.isNotEmpty) throw StateError(s.error);
      s._sender = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => s._sendInput(),
      );
      return s;
    } catch (_) {
      s.dispose();
      rethrow;
    }
  }

  Future<void> _accept(HttpRequest request) async {
    WebSocket? socket;
    int? reserved;
    try {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      String? rejection;
      if (_closed || error.isNotEmpty)
        rejection = 'The room has closed.';
      else if (request.uri.path != '/join' ||
          request.uri.queryParameters['v'] != '$protocolVersion') {
        rejection =
            'Different game version. Install the same APK on every phone.';
      } else if (request.uri.queryParameters['code'] != code)
        rejection = 'Incorrect room code.';
      else if (started)
        rejection = 'This match has already started. Join a new room.';
      else {
        for (var i = 1; i < 4; i++) {
          if (!_peers.containsKey(i) && !_reserved.contains(i)) {
            reserved = i;
            break;
          }
        }
        if (reserved == null) rejection = 'This room is full (4 players).';
      }
      if (reserved != null) _reserved.add(reserved);
      socket = await WebSocketTransformer.upgrade(request);
      if (rejection != null || _closed || started) {
        _send(socket, {
          'type': 'error',
          'message': rejection ?? 'The match has started.',
        });
        await socket.close();
        return;
      }
      final id = reserved!;
      socket.pingInterval = const Duration(seconds: 3);
      _peers[id] = socket;
      _inputs[id] = Offset.zero;
      _lastInput[id] = DateTime.now();
      members[id] = 'Player ${id + 1} · Rebel';
      _send(socket, {'type': 'welcome', 'seat': id, 'arena': arenaIndex});
      final acceptedSocket = socket;
      socket.listen(
        (data) {
          if (_peers[id] == acceptedSocket) _command(id, data);
        },
        onDone: () => _remove(id, acceptedSocket),
        onError: (_) => _remove(id, acceptedSocket),
      );
      _broadcastLobby();
    } catch (_) {
      socket?.close();
    } finally {
      if (reserved != null) _reserved.remove(reserved);
    }
  }

  void _remove(int id, WebSocket socket) {
    if (_closed || _peers[id] != socket) return;
    _peers.remove(id)?.close();
    _inputs.remove(id);
    _lastInput.remove(id);
    _lastAction.remove(id);
    members.remove(id);
    match?.targets.remove(id);
    _broadcastLobby();
  }

  void _command(int id, dynamic raw) {
    if (_closed || !_peers.containsKey(id)) return;
    try {
      final message = _decode(raw);
      switch (message['type']) {
        case 'input':
          final x = message['x'], y = message['y'];
          if (x is! num || y is! num || !x.isFinite || !y.isFinite) return;
          var movement = Offset(x.toDouble(), y.toDouble());
          if (movement.distance > 1) movement /= movement.distance;
          _inputs[id] = paused ? Offset.zero : movement;
          _lastInput[id] = DateTime.now();
        case 'action':
          final now = DateTime.now();
          if (now.difference(_lastAction[id] ?? DateTime(2000)).inMilliseconds <
              120)
            return;
          _lastAction[id] = now;
          final kind = message['kind'];
          if (kind == 'primary' || kind == 'secondary') {
            final result = _act(id, kind);
            _send(_peers[id]!, {'type': 'feedback', 'message': result});
            if (started) _broadcast(_state());
          }
      }
    } catch (_) {
      _peers[id]?.close(
        WebSocketStatus.invalidFramePayloadData,
        'Invalid command',
      );
    }
  }

  Map<String, dynamic> _decode(dynamic raw) {
    if (raw is! String || raw.length > 20000)
      throw const FormatException('Invalid message');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  int _remoteArena = 0;
  void _receive(dynamic raw) {
    if (_closed || error.isNotEmpty) return;
    try {
      final message = _decode(raw);
      switch (message['type']) {
        case 'welcome':
          seat = message['seat'] as int;
          _remoteArena = message['arena'] as int;
          if (seat < 1 ||
              seat > 3 ||
              _remoteArena < 0 ||
              _remoteArena >= arenas.length) {
            throw const FormatException('Invalid room');
          }
          if (!_welcome.isCompleted) _welcome.complete();
        case 'lobby':
          members = {
            for (final item in message['members'] as List)
              item['seat'] as int: item['name'] as String,
          };
        case 'state':
          final nextRound = message['round'] as int;
          if (nextRound != round || match == null) {
            round = nextRound;
            match = Match(arenas[_remoteArena], seat, 0);
            _movement = Offset.zero;
          }
          paused = message['paused'] as bool;
          applySnapshot(match!, message['match'] as Map<String, dynamic>);
        case 'feedback':
          feedback = message['message'] as String;
          feedbackRevision++;
        case 'error':
          _fail(message['message'] as String);
          return;
      }
      notifyListeners();
    } catch (_) {
      _fail('Incompatible game data. Install the same APK on every phone.');
    }
  }

  void startMatch() {
    if (!isHost ||
        _closed ||
        error.isNotEmpty ||
        members.length < 2 ||
        (match != null && !match!.ended))
      return;
    round++;
    paused = false;
    _movement = Offset.zero;
    for (final id in _inputs.keys.toList()) {
      _inputs[id] = Offset.zero;
    }
    match = Match(arenas[arenaIndex], 0, DateTime.now().microsecondsSinceEpoch);
    _broadcast(_state());
    notifyListeners();
  }

  Map<String, dynamic> _state() => {
    'type': 'state',
    'round': round,
    'paused': paused,
    'match': matchSnapshot(match!),
  };

  void _broadcastLobby() {
    _broadcast({
      'type': 'lobby',
      'members': [
        for (final entry in members.entries)
          {'seat': entry.key, 'name': entry.value},
      ],
    });
    notifyListeners();
  }

  void setMovement(Offset value) {
    if (_closed || error.isNotEmpty) return;
    _movement = value;
    if (isHost)
      _inputs[0] = paused ? Offset.zero : value;
    else
      _sendInput();
  }

  void _sendInput() {
    if (_closed || _socket == null || error.isNotEmpty) return;
    _send(_socket!, {'type': 'input', 'x': _movement.dx, 'y': _movement.dy});
  }

  void setPaused(bool value) {
    setMovement(Offset.zero);
    if (!isHost || !started) return;
    paused = value;
    for (final id in _inputs.keys.toList()) {
      _inputs[id] = Offset.zero;
    }
    _broadcast(_state());
    notifyListeners();
  }

  void action(String kind) {
    if (_closed || error.isNotEmpty || !started || paused) return;
    if (isHost) {
      feedback = _act(0, kind);
      feedbackRevision++;
      _broadcast(_state());
      notifyListeners();
    } else {
      _send(_socket!, {'type': 'action', 'kind': kind});
    }
  }

  String _act(int id, String kind) {
    final m = match;
    if (m == null || paused || m.ended) return '';
    if (kind == 'secondary') return m.secondary(id);
    if (!m.primary(id))
      return id == 0
          ? 'Capture is not ready.'
          : 'Move closer to an unoccupied object.';
    if (id == 0)
      return m.captureHit
          ? 'Rebel captured!'
          : 'Miss! Get within the capture circle.';
    return m.players[id].hidingIn == null
        ? 'You left your hiding place.'
        : 'Hidden. Move or tap Leave to come out.';
  }

  void _send(WebSocket socket, Map<String, dynamic> data) {
    if (socket.readyState == WebSocket.open) socket.add(jsonEncode(data));
  }

  void _broadcast(Map<String, dynamic> data) {
    for (final socket in _peers.values) {
      _send(socket, data);
    }
  }

  void _fail(String message) {
    if (_closed || error.isNotEmpty) return;
    error = message;
    _movement = Offset.zero;
    _sender?.cancel();
    _ticker?.cancel();
    _socket?.close();
    if (!_welcome.isCompleted) _welcome.complete();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _ticker?.cancel();
    _sender?.cancel();
    _socket?.close();
    for (final socket in _peers.values) {
      _send(socket, {'type': 'error', 'message': 'The host closed the room.'});
      socket.close();
    }
    _peers.clear();
    _server?.close(force: true);
    super.dispose();
  }
}
