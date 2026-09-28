import 'package:flutter/material.dart';

abstract final class PartyColors {
  static const cream = Color(0xFFFFF4E4);
  static const ink = Color(0xFF241C33);
  static const coral = Color(0xFFFF5D73);
  static const tangerine = Color(0xFFFF8A3D);
  static const sun = Color(0xFFFFC857);
  static const mint = Color(0xFF1FCBB0);
  static const grape = Color(0xFF7C5CFF);
  static const sky = Color(0xFF4C9BE8);
  static const card = Color(0xFFFFFBF6);

  static const avatar = <Color>[coral, mint, grape, sun, sky, tangerine];
}

ThemeData buildPartyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: PartyColors.cream,
    fontFamily: 'Fredoka',
    colorScheme: ColorScheme.fromSeed(seedColor: PartyColors.coral).copyWith(
      primary: PartyColors.coral,
      onPrimary: Colors.white,
      surface: PartyColors.card,
      onSurface: PartyColors.ink,
    ),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: const BorderSide(color: PartyColors.ink, width: 3),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Fredoka',
      bodyColor: PartyColors.ink,
      displayColor: PartyColors.ink,
    ),
    splashFactory: InkRipple.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: PartyColors.grape,
      selectionColor: Color(0x667C5CFF),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: TextStyle(
        color: PartyColors.ink.withValues(alpha: 0.45),
        fontWeight: FontWeight.w500,
        fontSize: 18,
      ),
      labelStyle: const TextStyle(
        color: PartyColors.ink,
        fontWeight: FontWeight.w600,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: PartyColors.grape, width: 3),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: PartyColors.coral, width: 3),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: PartyColors.coral, width: 3),
      ),
    ),
  );
}
