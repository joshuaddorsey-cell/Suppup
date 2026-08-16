import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class SuppupApp extends StatelessWidget {
  const SuppupApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suppup',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home ?? const HomeScreen(),
    );
  }
}
