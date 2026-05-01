import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color orange     = Color(0xFFF97316);
  static const Color orangeLight= Color(0xFFFEF3E8);
  static const Color dark       = Color(0xFF1A1F2E);
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color textPrimary= Color(0xFF111827);
  static const Color textMuted  = Color(0xFF6B7280);
  static const Color border     = Color(0xFFE5E7EB);
  static const Color success    = Color(0xFF10B981);
  static const Color danger     = Color(0xFFEF4444);

  static ThemeData get light => ThemeData(
    useMaterial3:     true,
    fontFamily:       'DMSans',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor:  orange,
      primary:    orange,
      surface:    surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: orange,
      foregroundColor: Colors.white,
      elevation:       0,
      centerTitle:     false,
      titleTextStyle:  TextStyle(
        fontFamily:  'DMSans',
        fontWeight:  FontWeight.w600,
        fontSize:    18,
        color:       Colors.white,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior:         SnackBarBehavior.floating,
      backgroundColor:  dark,
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'DMSans'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
