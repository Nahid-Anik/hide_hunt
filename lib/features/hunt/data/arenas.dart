import 'dart:ui';
import '../domain/models/arena.dart';

final arenas = <Arena>[
  Arena("The Courtyard", const Color(0xffc5d2a4), [
    const Rect.fromLTWH(225, 145, 35, 205),
    const Rect.fromLTWH(225, 440, 35, 130),
    const Rect.fromLTWH(450, 230, 170, 32),
    const Rect.fromLTWH(450, 430, 170, 32),
    const Rect.fromLTWH(735, 150, 32, 190),
    const Rect.fromLTWH(735, 430, 32, 150),
  ]),
  Arena("The Orchard", const Color(0xffbacd99), [
    const Rect.fromLTWH(190, 140, 180, 35),
    const Rect.fromLTWH(570, 140, 180, 35),
    const Rect.fromLTWH(320, 285, 35, 180),
    const Rect.fromLTWH(605, 285, 35, 180),
    const Rect.fromLTWH(190, 545, 180, 35),
    const Rect.fromLTWH(570, 545, 180, 35),
  ]),
  Arena("Quiet Harbor", const Color(0xffb6ccc7), [
    const Rect.fromLTWH(180, 130, 40, 180),
    const Rect.fromLTWH(180, 410, 40, 180),
    const Rect.fromLTWH(370, 190, 210, 35),
    const Rect.fromLTWH(370, 495, 210, 35),
    const Rect.fromLTWH(740, 130, 40, 180),
    const Rect.fromLTWH(740, 410, 40, 180),
  ]),
  Arena("Amber Ruins", const Color(0xffd7c6a0), [
    const Rect.fromLTWH(190, 150, 140, 35),
    const Rect.fromLTWH(190, 150, 35, 120),
    const Rect.fromLTWH(630, 150, 140, 35),
    const Rect.fromLTWH(735, 150, 35, 120),
    const Rect.fromLTWH(190, 450, 35, 120),
    const Rect.fromLTWH(190, 535, 140, 35),
    const Rect.fromLTWH(735, 450, 35, 120),
    const Rect.fromLTWH(630, 535, 140, 35),
    const Rect.fromLTWH(450, 275, 45, 170),
  ]),
  Arena("Frostwood", const Color(0xffd7e4dd), [
    const Rect.fromLTWH(210, 130, 160, 50),
    const Rect.fromLTWH(590, 130, 160, 50),
    const Rect.fromLTWH(210, 530, 160, 50),
    const Rect.fromLTWH(590, 530, 160, 50),
    const Rect.fromLTWH(170, 290, 100, 130),
    const Rect.fromLTWH(690, 290, 100, 130),
    const Rect.fromLTWH(425, 210, 110, 35),
    const Rect.fromLTWH(425, 475, 110, 35),
  ]),
];
