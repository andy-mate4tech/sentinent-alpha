import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sentient Alpha terminal tokens (U1).
class SA {
  static const canvas = Color(0xFF0B0F19);
  static const mint = Color(0xFF10B981);
  static const cyan = Color(0xFF38BDF8);
  static const coral = Color(0xFFF43F5E);
  static const hairline = Color(0x14FFFFFF);
  static const surface = Color(0xFF121826);
  static const muted = Color(0xFF94A3B8);
  static const text = Color(0xFFE2E8F0);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.dark(
        primary: mint,
        secondary: cyan,
        error: coral,
        surface: surface,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: text,
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: hairline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mint),
        ),
        hintStyle: const TextStyle(color: muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: canvas,
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: mint.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = text,
  }) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);
}

const kDisclaimer = '''
Sentient Alpha is a research and bookkeeping tool. Ratings, scores, scenarios, and copilot text are informational and may be wrong. They are not financial, investment, tax, or trading advice, and not an offer to buy or sell any security. TradingAgents is a research framework; past or simulated results do not predict future results. You can lose money. You are responsible for your own decisions. If you need advice, consult a licensed professional in your jurisdiction.
''';

const kDisclaimerShort = 'Informational only — not a trade instruction.';
