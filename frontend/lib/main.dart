import 'package:flutter/material.dart';
import 'theme.dart';
import 'auth/login_screen.dart';

void main() => runApp(const NidaaCareApp());

class NidaaCareApp extends StatelessWidget {
  const NidaaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NidaaCare',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LoginScreen(),
    );
  }
}