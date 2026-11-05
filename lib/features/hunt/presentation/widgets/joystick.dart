import 'package:flutter/material.dart';

class Joystick extends StatefulWidget {
  final ValueChanged<Offset> changed;
  const Joystick({super.key, required this.changed});
  @override
  State<Joystick> createState() => _Joystick();
}

class _Joystick extends State<Joystick> {
  Offset delta = Offset.zero;
  int? pointer;
  void move(Offset at) {
    var d = at - const Offset(55, 55);
    if (d.distance > 35) d = d / d.distance * 35;
    setState(() => delta = d);
    widget.changed(d / 35);
  }

  void reset() {
    pointer = null;
    setState(() => delta = Offset.zero);
    widget.changed(Offset.zero);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      if (pointer == null) {
        pointer = e.pointer;
        move(e.localPosition);
      }
    },
    onPointerMove: (e) {
      if (pointer == e.pointer) move(e.localPosition);
    },
    onPointerUp: (e) {
      if (pointer == e.pointer) reset();
    },
    onPointerCancel: (e) {
      if (pointer == e.pointer) reset();
    },
    child: Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          colors: [Color(0xbb42634e), Color(0xbb1e3b32)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xbbd1deb1), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4420342b),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Transform.translate(
          offset: delta,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-.3, -.5),
                colors: [Color(0xfff5ffd5), Color(0xffb9d58b)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x66304935),
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}
