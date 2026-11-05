import 'dart:ui';
import 'prop.dart';

class Pawn {
  Offset at;
  final bool hunter;
  Prop? hidingIn;
  bool caught = false;
  double cooldown = 0, skill = 0, vanish = 0;
  Pawn(this.at, this.hunter);
}
