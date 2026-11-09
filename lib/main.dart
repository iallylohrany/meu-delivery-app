import 'config/app_theme.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MeuDeliveryApp());
}

class MeuDeliveryApp extends StatelessWidget {
  const MeuDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const SplashScreen(),
    );
  }
}
