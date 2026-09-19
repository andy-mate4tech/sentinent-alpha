import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SA {
  static const canvas = Color(0xFF0B0F19);
  static const surface = Color(0xFF0F172A);
  static const surface2 = Color(0xFF1E293B);
  static const surfaceHigh = Color(0xFF273647);
  static const line = Color(0x14FFFFFF);
  static const lineStrong = Color(0x22FFFFFF);
  static const mint = Color(0xFF10B981);
  static const mintSoft = Color(0xFF4EDEA3);
  static const cyan = Color(0xFF38BDF8);
  static const cyanBright = Color(0xFF7BD0FF);
  static const coral = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const mintWash = Color(0x2610B981);
  static const coralWash = Color(0x1AF43F5E);
  static const cyanWash = Color(0x2638BDF8);
}

ThemeData buildSentientTheme() {
  const textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.23,
      letterSpacing: -0.5,
      color: SA.text,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: SA.text,
    ),
    titleMedium: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: SA.text,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: SA.text,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: SA.text,
    ),
    bodySmall: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: SA.muted,
    ),
    labelMedium: TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: SA.muted,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SA.canvas,
    colorScheme: const ColorScheme.dark(
      surface: SA.surface,
      primary: SA.mint,
      secondary: SA.cyan,
      error: SA.coral,
      onPrimary: Color(0xFF003824),
      onSurface: SA.text,
    ),
    textTheme: textTheme,
    fontFamily: 'PlusJakartaSans',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    dividerColor: SA.lineStrong,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SA.surface2,
      labelStyle: const TextStyle(color: SA.muted, fontSize: 13),
      hintStyle: const TextStyle(color: SA.muted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SA.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SA.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SA.mint),
      ),
    ),
  );
}
