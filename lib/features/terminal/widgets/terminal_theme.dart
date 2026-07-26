import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// 依据当前 Material 主题生成 xterm 配色。
///
/// 背景 / 前景 / 光标 / 选区取自 [ColorScheme]（保证深浅色一致），
/// 16 色 ANSI 调色板按亮暗分别使用对比度合适的固定值
/// （深色沿用 VS Code Dark+，浅色沿用 VS Code Light+）。
TerminalTheme buildTerminalTheme(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  final background = scheme.surfaceContainerLowest;
  final foreground = scheme.onSurface;

  if (isDark) {
    return TerminalTheme(
      cursor: scheme.primary,
      selection: scheme.primary.withValues(alpha: 0.32),
      foreground: foreground,
      background: background,
      black: const Color(0xFF3B4048),
      red: const Color(0xFFF14C4C),
      green: const Color(0xFF23D18B),
      yellow: const Color(0xFFE5E510),
      blue: const Color(0xFF3B8EEA),
      magenta: const Color(0xFFBC3FBC),
      cyan: const Color(0xFF29B8DB),
      white: const Color(0xFFD4D4D4),
      brightBlack: const Color(0xFF666666),
      brightRed: const Color(0xFFFF6E6E),
      brightGreen: const Color(0xFF4AF6A3),
      brightYellow: const Color(0xFFF5F543),
      brightBlue: const Color(0xFF6BB2F5),
      brightMagenta: const Color(0xFFD670D6),
      brightCyan: const Color(0xFF56D9F0),
      brightWhite: const Color(0xFFFFFFFF),
      searchHitBackground: const Color(0xFFFFD54F),
      searchHitBackgroundCurrent: const Color(0xFF7CFF6B),
      searchHitForeground: const Color(0xFF000000),
    );
  }

  return TerminalTheme(
    cursor: scheme.primary,
    selection: scheme.primary.withValues(alpha: 0.24),
    foreground: foreground,
    background: background,
    black: const Color(0xFF000000),
    red: const Color(0xFFCD3131),
    green: const Color(0xFF107C10),
    yellow: const Color(0xFF949800),
    blue: const Color(0xFF0451A5),
    magenta: const Color(0xFFBC05BC),
    cyan: const Color(0xFF0598BC),
    white: const Color(0xFF555555),
    brightBlack: const Color(0xFF666666),
    brightRed: const Color(0xFFCD3131),
    brightGreen: const Color(0xFF14CE14),
    brightYellow: const Color(0xFFB5BA00),
    brightBlue: const Color(0xFF0451A5),
    brightMagenta: const Color(0xFFBC05BC),
    brightCyan: const Color(0xFF0598BC),
    brightWhite: const Color(0xFF262626),
    searchHitBackground: const Color(0xFFFFE082),
    searchHitBackgroundCurrent: const Color(0xFFA5D6A7),
    searchHitForeground: const Color(0xFF000000),
  );
}
