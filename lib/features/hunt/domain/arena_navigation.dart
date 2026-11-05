import 'dart:math';
import 'dart:ui';
import 'models/arena.dart';

/// Collision, line-of-sight and grid routing for one arena.
class ArenaNavigation {
  final Arena arena;
  const ArenaNavigation(this.arena);
  bool blocked(Offset p, [double radius = 12]) =>
      p.dx < 25 ||
      p.dy < 25 ||
      p.dx > 935 ||
      p.dy > 695 ||
      arena.walls.any((w) => w.inflate(radius).contains(p));
  bool clear(Offset a, Offset b, [double radius = 0]) {
    final n = ((b - a).distance / 8).ceil();
    for (var i = 1; i <= n; i++) {
      final p = Offset.lerp(a, b, i / n)!;
      if (radius > 0
          ? blocked(p, radius)
          : arena.walls.any((w) => w.contains(p)))
        return false;
    }
    return true;
  }

  Offset? route(Offset p, Offset target) {
    if (clear(p, target, 14)) return target;
    int key(Offset p) => (p.dy / 30).floor() * 32 + (p.dx / 30).floor();
    Offset point(int k) => Offset((k % 32) * 30 + 15, (k ~/ 32) * 30 + 15);
    final start = key(p),
        queue = <int>[key(p)],
        seen = <int>{key(p)},
        previous = <int, int>{};
    int? found;
    for (var i = 0; i < queue.length; i++) {
      final a = queue[i], at = point(a);
      if ((at - target).distance < 45 && clear(at, target, 14)) {
        found = a;
        break;
      }
      for (final d in [
        const Point(1, 0),
        const Point(-1, 0),
        const Point(0, 1),
        const Point(0, -1),
      ]) {
        final x = a % 32 + d.x, y = a ~/ 32 + d.y;
        if (x < 0 || x >= 32 || y < 0 || y >= 24) continue;
        final b = y * 32 + x, q = point(b);
        if (!seen.contains(b) &&
            !blocked(q, 16) &&
            clear(i == 0 ? p : at, q, 14)) {
          seen.add(b);
          previous[b] = a;
          queue.add(b);
        }
      }
    }
    if (found == null) return null;
    var cursor = found;
    while (previous.containsKey(cursor) && previous[cursor] != start) {
      cursor = previous[cursor]!;
    }
    return point(cursor);
  }
}
