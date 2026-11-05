import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final double cooldown;
  final VoidCallback onPressed;
  final bool enabled;
  const ActionButton({
    super.key,
    required this.label,
    required this.cooldown,
    required this.onPressed,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final ready = enabled && cooldown <= 0;
    final icon = switch (label) {
      'Capture' => Icons.radar_rounded,
      'Sense' => Icons.explore_outlined,
      'Hide' => Icons.inventory_2_outlined,
      'Leave' => Icons.logout_rounded,
      _ => Icons.auto_awesome_rounded,
    };
    final total = label == 'Capture' ? 4.0 : 20.0;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-.4, -.5),
                colors: ready
                    ? [const Color(0xfff4ffc8), const Color(0xffb4d978)]
                    : [const Color(0xff506d60), const Color(0xff2a493f)],
              ),
              border: Border.all(
                color: ready
                    ? const Color(0xfffff0b9)
                    : const Color(0xff7a9680),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x5520342b),
                  blurRadius: 9,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: const Color(0xff30482f),
                disabledForegroundColor: const Color(0xffdfebd4),
              ),
              onPressed: ready ? onPressed : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 26),
                  const SizedBox(height: 3),
                  Text(
                    cooldown > 0 ? '${cooldown.ceil()}s' : label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (cooldown > 0)
                    Text(label, style: const TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
          if (enabled && cooldown > 0)
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: CircularProgressIndicator(
                  value: (1 - cooldown / total).clamp(0.0, 1.0),
                  strokeWidth: 3,
                  color: const Color(0xffe9d99e),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
