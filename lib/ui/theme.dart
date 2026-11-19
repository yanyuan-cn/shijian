/// 设计令牌。颜色全部照搬旧 HTML 的暗色皮肤，改名开关只有这一处。
library;

import 'package:flutter/material.dart';

class C {
  C._();
  static const bg = Color(0xFF0E1116);
  static const panel = Color(0xFF141922);
  static const panel2 = Color(0xFF1A212C);
  static const bar = Color(0xFF12161D);
  static const line = Color(0x1FFFFFFF);
  static const text = Color(0xFFE7EBF2);
  static const text2 = Color(0xFF98A3B6);
  static const text3 = Color(0xFF5F6B7E);
  static const accent = Color(0xFF7DA7FF);
  static const accent2 = Color(0xFFA7C4FF);
  static const danger = Color(0xFFFF7A7A);
}

class T {
  T._();
  /// 安卓上的 serif = Noto Serif CJK，接近原型的 Georgia/Songti SC 气质。
  static const serif = 'serif';
  static const sans = 'sans-serif';

  static const logo = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700, color: C.text, height: 1.1);
  static const sub = TextStyle(fontSize: 12, color: C.text2, height: 1.1);
  static const kicker = TextStyle(
      fontSize: 12, color: C.text3, letterSpacing: 0.6, height: 1.2);
  static const body = TextStyle(fontSize: 14, color: C.text, height: 1.55);
  static const bodyDim = TextStyle(fontSize: 13, color: C.text2, height: 1.5);
  static const small = TextStyle(fontSize: 11.5, color: C.text3, height: 1.4);
  static const sectionTitle = TextStyle(
      fontFamily: serif,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: C.text,
      height: 1.3);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: C.panel,
      primary: C.accent,
      secondary: C.accent2,
      onSurface: C.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: C.text,
      displayColor: C.text,
      fontFamilyFallback: const ['Noto Sans CJK SC', 'sans-serif'],
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.panel2,
      contentTextStyle: TextStyle(color: C.text, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: C.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.panel2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: const TextStyle(color: C.text3, fontSize: 14),
      labelStyle: const TextStyle(color: C.text2, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: C.accent.withValues(alpha: 0.55)),
      ),
    ),
  );
}
