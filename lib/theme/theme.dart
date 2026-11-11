import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildLapsoTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: LapsoColors.primary,
    primary: LapsoColors.primary,
    onPrimary: Colors.white,
    surface: LapsoColors.surface,
    onSurface: LapsoColors.navy,
    error: LapsoColors.bad,
  );

  const OutlineInputBorder fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(LapsoRadius.field)),
    borderSide: BorderSide(color: LapsoColors.control, width: 1.5),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: LapsoText.body,
    scaffoldBackgroundColor: LapsoColors.ground,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, color: LapsoColors.navy),
      bodyMedium: TextStyle(fontSize: 15, color: LapsoColors.navy),
      bodySmall: TextStyle(fontSize: 13, color: LapsoColors.muted),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: LapsoColors.navy,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: LapsoColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: LapsoText.body,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: LapsoColors.navy,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LapsoColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: LapsoColors.line,
        disabledForegroundColor: LapsoColors.muted,
        minimumSize: const Size.fromHeight(56),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LapsoRadius.button)),
        ),
        textStyle: const TextStyle(
          fontFamily: LapsoText.body,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LapsoColors.navy,
        backgroundColor: LapsoColors.surface,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: LapsoColors.control, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LapsoRadius.button)),
        ),
        textStyle: const TextStyle(
          fontFamily: LapsoText.body,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LapsoColors.primaryDark,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: LapsoText.body,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: LapsoColors.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(LapsoRadius.field)),
        borderSide: BorderSide(color: LapsoColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(LapsoRadius.field)),
        borderSide: BorderSide(color: LapsoColors.bad, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(LapsoRadius.field)),
        borderSide: BorderSide(color: LapsoColors.bad, width: 2),
      ),
      errorStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: LapsoColors.bad,
      ),
      errorMaxLines: 3,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: LapsoColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: LapsoColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
        Set<WidgetState> states,
      ) {
        final bool selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: LapsoText.body,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? LapsoColors.primary : LapsoColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
        Set<WidgetState> states,
      ) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? LapsoColors.primary : LapsoColors.muted,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LapsoColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LapsoRadius.sheet),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LapsoColors.navy,
      contentTextStyle: TextStyle(
        fontFamily: LapsoText.body,
        fontSize: 15,
        color: Colors.white,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: LapsoColors.lineSoft,
      thickness: 1,
      space: 1,
    ),
  );
}
