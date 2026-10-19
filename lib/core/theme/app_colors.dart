import 'package:flutter/material.dart';

class AppColors {
  // Dynamic theme controller toggle
  static bool isDark = true;

  // Backgrounds (Matte near-black, neutral — no blue tint — vs warm paper light)
  static Color get bgDark =>
      isDark ? const Color(0xFF0B0B0C) : const Color(0xFFF6F6F2);
  static Color get bgSidebar =>
      isDark ? const Color(0xFF111112) : const Color(0xFFFFFFFF);
  static Color get bgCard =>
      isDark ? const Color(0xFF161618) : const Color(0xFFFFFFFF);
  static Color get bgCardHover =>
      isDark ? const Color(0xFF1E1E21) : const Color(0xFFEEEEE8);
  static Color get border =>
      isDark ? const Color(0xFF232326) : const Color(0xFFE3E3DC);
  static Color get borderLight =>
      isDark ? const Color(0xFF34343A) : const Color(0xFFCFCFC6);

  // Primary: Bright Matte Blue ("Biru Doff Cerah")
  static const Color primary = Color(0xFF3B82F6);
  // Accent text/icon tint: clear matte azure in dark mode, rich cobalt in light mode
  static Color get primaryLight =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  // Text/icons drawn ON a solid primary fill (white for crisp contrast)
  static const Color onPrimary = Colors.white;

  // Curated matte vibrant folder palette (for colorful, non-monotonous Bento tiles)
  static const List<Color> folderPalette = [
    Color(0xFF3B82F6), // Matte Bright Azure Blue
    Color(0xFF8B5CF6), // Matte Iris Purple
    Color(0xFF10B981), // Matte Mint Emerald
    Color(0xFFF59E0B), // Matte Golden Amber
    Color(0xFFEC4899), // Matte Rose Pink
    Color(0xFF06B6D4), // Matte Electric Cyan
    Color(0xFFF97316), // Matte Tangerine Orange
    Color(0xFF6366F1), // Matte Indigo
    Color(0xFF14B8A6), // Matte Jade Teal
    Color(0xFFA855F7), // Matte Violet
    Color(0xFFE11D48), // Matte Coral Crimson
    Color(0xFF84CC16), // Matte Lime
  ];

  /// Returns a deterministic, beautiful matte color for folder tiles.
  static Color getFolderColor(String name, [int index = 0]) {
    if (name.isEmpty) return folderPalette[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final idx = (hash + index * 5) % folderPalette.length;
    return folderPalette[idx];
  }

  // Vibrant Distinct Category Palette (Zero Ambiguity & High Contrast)
  static const Color catInstaller = Color(
    0xFFFF3B30,
  ); // 💿 Electric Scarlet Fire (0° Hue)
  static const Color catImage = Color(
    0xFFF59E0B,
  ); // 🖼️ Sunny Golden Tangerine (38° Hue)
  static const Color catCode = Color(
    0xFF10B981,
  ); // 💻 Sweet Emerald Green (152° Hue)
  static const Color catAudio = Color(
    0xFF06B6D4,
  ); // 🎵 Electric Turquoise / Cyan (188° Hue)
  static const Color catDocument = Color(
    0xFF0284C7,
  ); // 📄 Vibrant Sky Blue (200° Hue)
  static const Color catArchive = Color(
    0xFF8B5CF6,
  ); // 📦 Deep Royal Violet (258° Hue)
  static const Color catVideo = Color(
    0xFFD946EF,
  ); // 🎬 Vibrant Fuchsia / Orchid (292° Hue)
  static const Color catOther = Color(
    0xFF64748B,
  ); // 📁 Soft Slate Gray (Neutral)

  // Weight Tiers (Cartoon Animal Icons)
  static const Color tierTitan = Color(
    0xFFFF1744,
  ); // 🐋 Titan Whale (>1GB) - Vivid Crimson
  static const Color tierHeavy = Color(
    0xFFFF6D00,
  ); // 🦣 Heavy Elephant (500MB - 1GB) - Deep Orange
  static const Color tierModerate = Color(
    0xFFFFD600,
  ); // 🦊 Moderate Fox (100MB - 500MB) - Honey Amber
  static const Color tierFeather = Color(
    0xFF00B0FF,
  ); // 🐣 Feather Chick (<100MB) - Sky Cyan

  // Feedback & Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFFB703);
  static const Color danger = Color(0xFFFF3B30);

  // Typography
  static Color get textPrimary =>
      isDark ? const Color(0xFFF2F2EE) : const Color(0xFF17171A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA1A1A6) : const Color(0xFF55555C);
  static Color get textMuted =>
      isDark ? const Color(0xFF6B6B72) : const Color(0xFF8C8C93);
  static Color get speechBubbleBg =>
      isDark ? const Color(0xFF18181A) : const Color(0xFFEFF6FF);
}
