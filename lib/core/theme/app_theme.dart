import 'package:flutter/material.dart';

export 'theme_mode_notifier.dart';

class AppColors {
  AppColors._();

  // Primary - Deep Blue
  static const primary50 = Color(0xFFE8F0FE);
  static const primary100 = Color(0xFFC5D8FB);
  static const primary200 = Color(0xFF9EBEF8);
  static const primary300 = Color(0xFF74A3F4);
  static const primary400 = Color(0xFF5490F1);
  static const primary500 = Color(0xFF2563EB);
  static const primary600 = Color(0xFF1D55D4);
  static const primary700 = Color(0xFF1546BC);
  static const primary800 = Color(0xFF0F38A4);
  static const primary900 = Color(0xFF062183);

  // Secondary - Slate
  static const secondary50 = Color(0xFFF8FAFC);
  static const secondary100 = Color(0xFFF1F5F9);
  static const secondary200 = Color(0xFFE2E8F0);
  static const secondary300 = Color(0xFFCBD5E1);
  static const secondary400 = Color(0xFF94A3B8);
  static const secondary500 = Color(0xFF64748B);
  static const secondary600 = Color(0xFF475569);
  static const secondary700 = Color(0xFF334155);
  static const secondary800 = Color(0xFF1E293B);
  static const secondary900 = Color(0xFF0F172A);

  // Accent - Amber
  static const accent50 = Color(0xFFFFFBEB);
  static const accent100 = Color(0xFFFEF3C7);
  static const accent200 = Color(0xFFFDE68A);
  static const accent300 = Color(0xFFFCD34D);
  static const accent400 = Color(0xFFFBBF24);
  static const accent500 = Color(0xFFF59E0B);
  static const accent600 = Color(0xFFD97706);

  // Success - Emerald
  static const success50 = Color(0xFFECFDF5);
  static const success100 = Color(0xFFD1FAE5);
  static const success500 = Color(0xFF10B981);
  static const success600 = Color(0xFF059669);
  static const success700 = Color(0xFF047857);

  // Warning - Orange
  static const warning50 = Color(0xFFFFF7ED);
  static const warning100 = Color(0xFFFFEDD5);
  static const warning500 = Color(0xFFF97316);
  static const warning600 = Color(0xFFEA580C);

  // Error - Red
  static const error50 = Color(0xFFFFF1F2);
  static const error100 = Color(0xFFFFE4E6);
  static const error500 = Color(0xFFEF4444);
  static const error600 = Color(0xFFDC2626);
  static const error700 = Color(0xFFB91C1C);

  // Neutrals
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const surface = Color(0xFFF8FAFC);
  static const surfaceDark = Color(0xFF1A2236);
  static const backgroundDark = Color(0xFF0F1623);
  static const cardDark = Color(0xFF1E293B);

  // ── Pink/Purple pastel theme ──
  static const pink50 = Color(0xFFFFF5FB);
  static const pink100 = Color(0xFFFFE6F4);
  static const pink200 = Color(0xFFFFCCE9);
  static const pink300 = Color(0xFFFFA8D8);
  static const pink400 = Color(0xFFFF85C8);
  static const pink500 = Color(0xFFEC5FAE);

  static const purple50 = Color(0xFFF7F2FF);
  static const purple100 = Color(0xFFECE0FF);
  static const purple200 = Color(0xFFDCC4FF);
  static const purple300 = Color(0xFFC59CFB);
  static const purple400 = Color(0xFFA873EE);
  static const purple500 = Color(0xFF8E5BDB);
  static const purple600 = Color(0xFF7444BE);
  static const purple700 = Color(0xFF5C3699);
  static const purple900 = Color(0xFF3B2466);

  static const pinkPurpleSurface = Color(0xFFFFF9FD);
  static const pinkPurpleBackground = Color(0xFFFDF6FC);
}

class AppTheme {
  AppTheme._();

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary500,
      brightness: Brightness.light,
      primary: AppColors.primary500,
      secondary: AppColors.secondary500,
      surface: AppColors.white,
      background: AppColors.surface,
      error: AppColors.error500,
    ),
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.secondary200,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.secondary900,
        letterSpacing: -0.2,
      ),
      iconTheme: const IconThemeData(color: AppColors.secondary700, size: 22),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.secondary200, width: 1),
      ),
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.all(0),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.secondary50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondary200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondary200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error500),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error500, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.secondary500,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.secondary400,
        fontSize: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary500,
        side: const BorderSide(color: AppColors.primary500),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary500,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      backgroundColor: AppColors.secondary100,
      selectedColor: AppColors.primary100,
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.secondary100,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: -0.5, color: AppColors.secondary900),
      displayMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.5, color: AppColors.secondary900),
      displaySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 24, letterSpacing: -0.3, color: AppColors.secondary900),
      headlineLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: -0.2, color: AppColors.secondary900),
      headlineMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: -0.2, color: AppColors.secondary900),
      headlineSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.secondary900),
      titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.secondary800),
      titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.secondary700),
      titleSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.secondary600),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 15, height: 1.5, color: AppColors.secondary800),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 14, height: 1.5, color: AppColors.secondary700),
      bodySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 12, height: 1.4, color: AppColors.secondary500),
      labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.secondary700),
      labelMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.secondary600),
      labelSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 11, color: AppColors.secondary500),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary500,
      unselectedItemColor: AppColors.secondary400,
      backgroundColor: AppColors.white,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w400),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary500,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.secondary900),
      contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.secondary600),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary500,
      brightness: Brightness.dark,
      primary: AppColors.primary400,
      secondary: AppColors.secondary400,
      surface: AppColors.cardDark,
      background: AppColors.backgroundDark,
      error: AppColors.error500,
    ),
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.white,
        letterSpacing: -0.2,
      ),
      iconTheme: const IconThemeData(color: AppColors.secondary300, size: 22),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2D3748), width: 1),
      ),
      color: AppColors.cardDark,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: -0.5, color: AppColors.white),
      displayMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.5, color: AppColors.white),
      headlineLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: -0.2, color: AppColors.white),
      headlineMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: -0.2, color: AppColors.white),
      headlineSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.white),
      titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.secondary100),
      titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.secondary200),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 15, height: 1.5, color: AppColors.secondary100),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 14, height: 1.5, color: AppColors.secondary200),
      bodySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 12, height: 1.4, color: AppColors.secondary400),
    ),
  );

  /// New: pastel pink + purple alternate theme
  static final pinkPurpleTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.purple500,
      brightness: Brightness.light,
      primary: AppColors.purple500,
      secondary: AppColors.pink500,
      surface: AppColors.pinkPurpleSurface,
      background: AppColors.pinkPurpleBackground,
      error: AppColors.error500,
    ),
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.pinkPurpleBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.pinkPurpleSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.pink100,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.purple900,
        letterSpacing: -0.2,
      ),
      iconTheme: const IconThemeData(color: AppColors.purple600, size: 22),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.pink200, width: 1),
      ),
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.all(0),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.pink50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.pink200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.pink200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.purple500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error500),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error500, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.purple400,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.pink300,
        fontSize: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.purple500,
        foregroundColor: AppColors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.purple500,
        side: const BorderSide(color: AppColors.purple500),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.purple500,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      backgroundColor: AppColors.pink100,
      selectedColor: AppColors.purple100,
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.pink100,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: -0.5, color: AppColors.purple900),
      displayMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.5, color: AppColors.purple900),
      displaySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 24, letterSpacing: -0.3, color: AppColors.purple900),
      headlineLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: -0.2, color: AppColors.purple900),
      headlineMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: -0.2, color: AppColors.purple900),
      headlineSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.purple900),
      titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.purple700),
      titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.purple600),
      titleSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.purple600),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 15, height: 1.5, color: AppColors.secondary800),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 14, height: 1.5, color: AppColors.secondary700),
      bodySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 12, height: 1.4, color: AppColors.secondary500),
      labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.purple600),
      labelMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.secondary600),
      labelSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 11, color: AppColors.secondary500),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.purple500,
      unselectedItemColor: AppColors.pink300,
      backgroundColor: AppColors.white,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w400),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.purple500,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.purple900),
      contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.secondary600),
    ),
  );
}
