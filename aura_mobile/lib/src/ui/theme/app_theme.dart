import 'package:flutter/material.dart';

/// AURA Design System — dark-first, minimal, focused on legibility during AI generation
class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color _brandPrimary = Color(0xFF7C6BFF); // soft indigo-violet
  static const Color _brandSecondary = Color(0xFF4ECDC4); // teal accent
  static const Color _brandError = Color(0xFFFF6B6B);
  static const Color _brandWarning = Color(0xFFFFD166);

  // Surface colors
  static const Color _surfaceBackground = Color(0xFF0E0E14);
  static const Color _surfaceCard = Color(0xFF1A1A26);
  static const Color _surfaceCardElevated = Color(0xFF22223A);
  static const Color _surfaceBorder = Color(0xFF2E2E4A);

  // Text colors
  static const Color _textPrimary = Color(0xFFF0F0FF);
  static const Color _textSecondary = Color(0xFFA0A0C0);
  static const Color _textMuted = Color(0xFF6060A0);

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _brandPrimary,
      onPrimary: Colors.white,
      secondary: _brandSecondary,
      onSecondary: Colors.black,
      error: _brandError,
      onError: Colors.white,
      surface: _surfaceCard,
      onSurface: _textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surfaceBackground,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceBackground,
        foregroundColor: _textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: _surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _surfaceBorder, width: 1),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brandPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: _textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceCardElevated,
        selectedColor: _brandPrimary.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: _surfaceBorder),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: _surfaceBorder,
        thickness: 1,
        space: 0,
      ),

      // Icon
      iconTheme: const IconThemeData(color: _textSecondary, size: 20),

      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: _textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: _textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: _textPrimary, fontSize: 15, height: 1.6),
        bodyMedium: TextStyle(
          color: _textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
        labelSmall: TextStyle(
          color: _textMuted,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Filled button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brandPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // List tile
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: _textPrimary,
        iconColor: _textSecondary,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _brandPrimary,
        linearTrackColor: _surfaceBorder,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceCardElevated,
        contentTextStyle: const TextStyle(color: _textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Convenience color accessors
  static const Color background = _surfaceBackground;
  static const Color card = _surfaceCard;
  static const Color cardElevated = _surfaceCardElevated;
  static const Color border = _surfaceBorder;
  static const Color primary = _brandPrimary;
  static const Color secondary = _brandSecondary;
  static const Color error = _brandError;
  static const Color warning = _brandWarning;
  static const Color textPrimary = _textPrimary;
  static const Color textSecondary = _textSecondary;
  static const Color textMuted = _textMuted;

  // Chat bubble colors
  static const Color bubbleUser = Color(0xFF2D2B6B);
  static const Color bubbleAssistant = _surfaceCard;
  static const Color bubbleUserBorder = Color(0xFF5A52CC);
  static const Color bubbleAssistantBorder = _surfaceBorder;

  // Status colors
  static const Color statusGenerating = _brandSecondary;
  static const Color statusReady = Color(0xFF51CF66);
  static const Color statusError = _brandError;
  static const Color statusLoading = _brandPrimary;
}
