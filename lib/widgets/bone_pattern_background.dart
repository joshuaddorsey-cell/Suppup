import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BonePatternBackground extends StatelessWidget {
  const BonePatternBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SuppupColors.cream,
        image: DecorationImage(
          image: AssetImage('assets/images/bone-paw-background.png'),
          fit: BoxFit.cover,
          opacity: 0.72,
        ),
      ),
      child: child,
    );
  }
}
