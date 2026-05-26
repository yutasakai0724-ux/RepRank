// ═══════════════════════════════════════════════
// Kinetic Performance デザインシステム
// プロジェクト: Rep Rank
// ID: 17765783634350002168
// ═══════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── カラーパレット ─────────────────────────────────
const Color kBackground          = Color(0xFF131313); // Deep Slate
const Color kSurface             = Color(0xFF131313); // same as bg
const Color kSurfaceContainerLow = Color(0xFF1C1B1B); // cards
const Color kSurfaceContainer    = Color(0xFF201F1F); // elevated cards
const Color kSurfaceContainerHigh= Color(0xFF2A2A2A); // inputs / rows
const Color kSurfaceHighest      = Color(0xFF353534); // modals
const Color kSurfaceBright       = Color(0xFF393939); // appbar

const Color kPrimary             = Color(0xFFFF6B00); // Orange (action)
const Color kPrimaryLight        = Color(0xFFFFB693); // Orange tint (text on dark)
const Color kOnPrimary           = Color(0xFF561F00); // text on orange btn
const Color kSecondary           = Color(0xFFADC6FF); // Electric Blue
const Color kSecondaryContainer  = Color(0xFF4B8EFF); // Blue active
const Color kTertiary            = Color(0xFF4DE082); // Success Green
const Color kTertiaryContainer   = Color(0xFF00B05A); // Green active

const Color kOnSurface           = Color(0xFFE5E2E1); // Primary text
const Color kOnSurfaceVariant    = Color(0xFFE2BFB0); // Secondary text (warm)
const Color kOutline             = Color(0xFFA98A7D); // Borders
const Color kOutlineVariant      = Color(0xFF5A4136); // Subtle borders

// ── テーマ ──────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBackground,
    colorScheme: ColorScheme.dark(
      primary: kPrimary,
      onPrimary: kOnPrimary,
      secondary: kSecondary,
      surface: kSurface,
      onSurface: kOnSurface,
      error: const Color(0xFFFFB4AB),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kSurfaceBright,
      foregroundColor: kOnSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w700,
        color: kOnSurface, letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: kOnSurface),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: kSurfaceContainer,
      selectedItemColor: kPrimary,
      unselectedItemColor: kOnSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: kOnPrimary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14, color: kOnSurfaceVariant.withValues(alpha: 0.5),
      ),
    ),
    dividerColor: kOutlineVariant.withValues(alpha: 0.4),
    cardTheme: CardThemeData(
      color: kSurfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kOutlineVariant.withValues(alpha: 0.6)),
      ),
    ),
  );
}
