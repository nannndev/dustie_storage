import 'package:flutter/material.dart';

class AppColors {
  // Dynamic theme controller toggle
  static bool isDark = true;

  // Backgrounds (Matte near-black, neutral — no blue tint — vs warm paper light)
  static Color get bgDark => isDark ? const Color(0xFF0B0B0C) : const Color(0xFFF6F6F2);
  static Color get bgSidebar => isDark ? const Color(0xFF111112) : const Color(0xFFFFFFFF);
  static Color get bgCard => isDark ? const Color(0xFF161618) : const Color(0xFFFFFFFF);
  static Color get bgCardHover => isDark ? const Color(0xFF1E1E21) : const Color(0xFFEEEEE8);
  static Color get border => isDark ? const Color(0xFF232326) : const Color(0xFFE3E3DC);
  static Color get borderLight => isDark ? const Color(0xFF34343A) : const Color(0xFFCFCFC6);

  // Primary: Dustie Lime
  static const Color primary = Color(0xFFB8F03C);
  // Accent text/icon tint: bright lime is unreadable on white, so use deep olive-lime in light mode
  static Color get primaryLight => isDark ? const Color(0xFFCCF56E) : const Color(0xFF4F7A00);
  static const Color primaryDark = Color(0xFF4F7A00);
  // Text/icons drawn ON a solid primary fill (lime is light, so this is near-black)
  static const Color onPrimary = Color(0xFF101400);

  // Vibrant Distinct Category Palette (Zero Ambiguity & High Contrast)
  static const Color catInstaller = Color(0xFFFF3B30); // 💿 Electric Scarlet Fire (0° Hue)
  static const Color catImage = Color(0xFFF59E0B);     // 🖼️ Sunny Golden Tangerine (38° Hue)
  static const Color catCode = Color(0xFF10B981);      // 💻 Sweet Emerald Green (152° Hue)
  static const Color catAudio = Color(0xFF06B6D4);     // 🎵 Electric Turquoise / Cyan (188° Hue)
  static const Color catDocument = Color(0xFF3B82F6);  // 📄 Royal Azure Sky Blue (217° Hue)
  static const Color catArchive = Color(0xFF8B5CF6);   // 📦 Deep Royal Violet (258° Hue)
  static const Color catVideo = Color(0xFFD946EF);     // 🎬 Vibrant Fuchsia / Orchid (292° Hue)
  static const Color catOther = Color(0xFF64748B);     // 📁 Soft Slate Gray (Neutral)

  // Weight Tiers (Cartoon Animal Icons)
  static const Color tierTitan = Color(0xFFFF1744);    // 🐋 Titan Whale (>1GB) - Vivid Crimson
  static const Color tierHeavy = Color(0xFFFF6D00);    // 🦣 Heavy Elephant (500MB - 1GB) - Deep Orange
  static const Color tierModerate = Color(0xFFFFD600); // 🦊 Moderate Fox (100MB - 500MB) - Honey Amber
  static const Color tierFeather = Color(0xFF00B0FF);  // 🐣 Feather Chick (<100MB) - Sky Cyan

  // Feedback & Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFFB703);
  static const Color danger = Color(0xFFFF3B30);

  // Typography
  static Color get textPrimary => isDark ? const Color(0xFFF2F2EE) : const Color(0xFF17171A);
  static Color get textSecondary => isDark ? const Color(0xFFA1A1A6) : const Color(0xFF55555C);
  static Color get textMuted => isDark ? const Color(0xFF6B6B72) : const Color(0xFF8C8C93);
  static Color get speechBubbleBg => isDark ? const Color(0xFF18181A) : const Color(0xFFF1F7E2);
}
