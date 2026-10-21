import 'package:flutter/material.dart';

const navy = Color(0xFF07111F);
const navyDeep = Color(0xFF050B14);
const navySoft = Color(0xFF10243A);
const teal = Color(0xFF18C8E8);
const gold = Color(0xFFFFA45B);
const line = Color(0xFF1C3447);
const muted = Color(0xFF91A7B8);
const canvas = Color(0xFF080F1A);
const surfaceColor = Color(0xFF0D1927);
const brightText = Color(0xFFEAF4FA);

TextStyle heading(double size, {Color color = brightText}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.2,
      color: color,
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: teal,
    brightness: Brightness.dark,
  ).copyWith(
    primary: teal,
    secondary: gold,
    surface: surfaceColor,
    onSurface: brightText,
    onSurfaceVariant: muted,
    outline: line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: brightText,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      hintStyle: const TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: navyDeep,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceColor,
      contentTextStyle: const TextStyle(color: brightText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}