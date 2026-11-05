import 'dart:ui';
import '../../hunt/domain/match.dart';
import '../../hunt/domain/models/prop.dart';

/// Full authoritative state. Clients never run rules or choose random props.
Map<String, dynamic> matchSnapshot(Match m) => {
  'time': m.time,
  'hiding': m.hiding,
  'ended': m.ended,
  'captures': m.captures,
  'winner': m.winner,
  'effect': m.captureEffect,
  'origin': [m.captureOrigin.dx, m.captureOrigin.dy],
  'hit': m.captureHit,
  'props': [
    for (final p in m.props) [p.at.dx, p.at.dy, p.kind],
  ],
  'players': [
    for (final p in m.players)
      {
        'at': [p.at.dx, p.at.dy],
        'caught': p.caught,
        'object': p.hidingIn == null ? -1 : m.props.indexOf(p.hidingIn!),
        'cooldown': p.cooldown,
        'skill': p.skill,
        'vanish': p.vanish,
      },
  ],
};

double _number(dynamic v) {
  if (v is! num || !v.isFinite) throw const FormatException('Invalid number');
  return v.toDouble();
}

Offset _point(dynamic v) => Offset(_number(v[0]), _number(v[1]));

void applySnapshot(Match m, Map<String, dynamic> data) {
  final props = data['props'] as List;
  final players = data['players'] as List;
  if (props.length != 48 || players.length != 4) {
    throw const FormatException('Invalid arena state');
  }
  // Preserve prop references when only player state changes.
  if (m.props.length != props.length ||
      List.generate(
        props.length,
        (i) =>
            m.props[i].at != _point(props[i]) || m.props[i].kind != props[i][2],
      ).any((v) => v)) {
    m.props
      ..clear()
      ..addAll(props.map((p) => Prop(_point(p), p[2] as int)));
  }
  m.time = _number(data['time']);
  m.hiding = data['hiding'] as bool;
  m.ended = data['ended'] as bool;
  m.captures = data['captures'] as int;
  m.winner = data['winner'] as String;
  m.captureEffect = _number(data['effect']);
  m.captureOrigin = _point(data['origin']);
  m.captureHit = data['hit'] as bool;
  for (var i = 0; i < 4; i++) {
    final p = m.players[i], state = players[i];
    final object = state['object'] as int;
    if (object < -1 || object >= m.props.length)
      throw const FormatException('Invalid object');
    p.at = _point(state['at']);
    p.caught = state['caught'] as bool;
    p.hidingIn = object == -1 ? null : m.props[object];
    p.cooldown = _number(state['cooldown']);
    p.skill = _number(state['skill']);
    p.vanish = _number(state['vanish']);
  }
}
