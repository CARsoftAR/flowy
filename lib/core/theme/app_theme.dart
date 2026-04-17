import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flowy App Color System
// Provides both a static fallback palette and a dynamic color engine
// that reacts to the current album artwork in real-time.
// ─────────────────────────────────────────────────────────────────────────────

class FlowyColors {
  FlowyColors._();

  // ── Brand Seed ────────────────────────────────────────────────────────────
  // ── Brand Seed ────────────────────────────────────────────────────────────
  static const Color brandSeed = Color(0xFF0078D4); // Cobalt Blue
  static const Color brandAccent = Color(0xFF2B88D8); // Vibrand Cobalt

  // ── Neutrals (Premium Charcoal) ─────────────────────────────────────────
  static const Color surface = Color(0xFF0F0F0F); // Very Dark Gray (Near Mica)
  static const Color surfaceVariant = Color(0xFF141414); // Deep Charcoal
  static const Color surfaceContainer = Color(0xFF1A1A1A); // Secondary
  static const Color surfaceElevated = Color(0xFF202020); // Top elements

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFE81123); // Windows Error Red
  static const Color success = Color(0xFF107C10); // Windows Success Green
  static const Color warning = Color(0xFFFFF100);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E); // Subtle Gray

  // ── Glow & Effects ────────────────────────────────────────────────────────
  static const Color glowPrimary = Color(0x330078D4);
  static const Color glowAccent = Color(0x220078D4);
}

// ─────────────────────────────────────────────────────────────────────────────
// FlowyTheme — Central theme configuration
// ─────────────────────────────────────────────────────────────────────────────

class FlowyTheme {
  FlowyTheme._();

  /// Builds the ThemeData from an optional [ColorScheme].
  /// When [colorScheme] is null, falls back to the brand seed palette.
  static ThemeData buildTheme({ColorScheme? colorScheme}) {
    final scheme = colorScheme ??
        ColorScheme.fromSeed(
          seedColor: FlowyColors.brandSeed,
          brightness: Brightness.dark,
          surface: FlowyColors.surface,
          onSurface: FlowyColors.textPrimary,
          primary: FlowyColors.brandSeed,
          secondary: FlowyColors.brandAccent,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,

      // ── Typography ──────────────────────────────────────────────────────
      textTheme: _buildTextTheme(scheme),

      // ── Scaffold & Background ───────────────────────────────────────────
      scaffoldBackgroundColor: scheme.surface,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: FlowyColors.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: FlowyColors.surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── NavigationBar ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FlowyColors.surface.withOpacity(0.95),
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : FlowyColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 24);
          }
          return IconThemeData(
              color: FlowyColors.textSecondary, size: 22);
        }),
        elevation: 0,
        height: 70,
      ),

      // ── Slider ──────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: Colors.white.withOpacity(0.1),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withOpacity(0.1),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      // ── Icon Button ─────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor:
              WidgetStateProperty.all(FlowyColors.textSecondary),
          overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }

  // ── Text Theme ─────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(ColorScheme scheme) {
    // Segoe UI Variable fallback to Inter
    final baseFont = GoogleFonts.inter(); 
    final baseTheme = GoogleFonts.interTextTheme();
    
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: FlowyColors.textPrimary,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: FlowyColors.textPrimary,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: FlowyColors.textPrimary,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: FlowyColors.textPrimary,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: FlowyColors.textPrimary,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: FlowyColors.textPrimary,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: FlowyColors.textPrimary,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: FlowyColors.textPrimary,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: FlowyColors.textPrimary,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: FlowyColors.textSecondary,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: FlowyColors.textSecondary,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: FlowyColors.textPrimary,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: FlowyColors.textSecondary,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: FlowyColors.textSecondary,
      ),
    );
  }

  // ── Glassmorphism Decoration ───────────────────────────────────────────────
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    double opacity = 0.08, // Subtle opacity for Mica/Acrylic feel
    Color? tintColor,
    double borderWidth = 0.5,
    bool showShadow = true, // Default to true for premium depth
  }) {
    final tint = tintColor ?? Colors.white;
    return BoxDecoration(
      color: tint.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: tint.withOpacity(0.12), // Very subtle border
        width: borderWidth,
      ),
      boxShadow: showShadow
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
              // Inner highlights simulation
              BoxShadow(
                color: tint.withOpacity(0.03),
                blurRadius: 1,
                spreadRadius: -1,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    );
  }

  // ── Gradient Backgrounds ──────────────────────────────────────────────────
  static BoxDecoration playerGradient(Color dominantColor) {
    final darkened = HSLColor.fromColor(dominantColor)
        .withLightness(0.08)
        .withSaturation(0.6)
        .toColor();
    final mid = HSLColor.fromColor(dominantColor)
        .withLightness(0.14)
        .withSaturation(0.5)
        .toColor();

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [darkened, mid, FlowyColors.surface],
        stops: const [0.0, 0.45, 1.0],
      ),
    );
  }

  // ── Glow Box Shadows ─────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.5}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.35 * intensity),
        blurRadius: 24,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withOpacity(0.15 * intensity),
        blurRadius: 48,
        spreadRadius: 8,
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HapticEngine — Tactile feedback orchestration
// ─────────────────────────────────────────────────────────────────────────────

class HapticEngine {
  HapticEngine._();

  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.vibrate(); // Fallback for success
}

// ─────────────────────────────────────────────────────────────────────────────
// DynamicPaletteService — Extracts palette from album art URL
// ─────────────────────────────────────────────────────────────────────────────

class DynamicPaletteService {
  static final DynamicPaletteService _instance =
      DynamicPaletteService._internal();
  factory DynamicPaletteService() => _instance;
  DynamicPaletteService._internal();

  Color? _cachedDominantColor;
  String? _cachedImageUrl;

  /// Returns the dominant color from [imageUrl].
  /// Caches results to avoid repeated network calls.
  Future<Color?> getDominantColor(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl == _cachedImageUrl) return _cachedDominantColor;

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 24,
        region: const Rect.fromLTWH(0, 0, 200, 200),
      );

      final color = generator.vibrantColor?.color ??
          generator.dominantColor?.color ??
          generator.mutedColor?.color;

      _cachedImageUrl = imageUrl;
      _cachedDominantColor = color;
      return color;
    } catch (_) {
      return null;
    }
  }

  /// Generates a full [ColorScheme] from the [dominantColor].
  ColorScheme buildSchemeFromColor(Color dominantColor) {
    return ColorScheme.fromSeed(
      seedColor: dominantColor,
      brightness: Brightness.dark,
    );
  }
}
