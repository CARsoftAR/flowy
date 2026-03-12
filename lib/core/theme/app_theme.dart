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
  static const Color brandSeed = Color(0xFF7C4DFF); // Electric Violet
  static const Color brandAccent = Color(0xFF00E5FF); // Cyan accent

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFF0D0D14);
  static const Color surfaceVariant = Color(0xFF12121E);
  static const Color surfaceContainer = Color(0xFF1A1A2E);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF5C7C);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB40);

  // ── Glow & Effects ────────────────────────────────────────────────────────
  static const Color glowPrimary = Color(0x557C4DFF);
  static const Color glowAccent = Color(0x4D00E5FF);
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
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: FlowyColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── NavigationBar ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FlowyColors.surfaceVariant.withOpacity(0.95),
        indicatorColor: scheme.primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(
              color: scheme.onSurface.withOpacity(0.5), size: 22);
        }),
        elevation: 0,
        height: 70,
      ),

      // ── Slider ──────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withOpacity(0.2),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withOpacity(0.15),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      // ── Icon Button ─────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor:
              WidgetStateProperty.all(scheme.onSurface.withOpacity(0.85)),
        ),
      ),

      // ── Page Transitions ────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Text Theme ─────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(ColorScheme scheme) {
    final baseTheme = GoogleFonts.outfitTextTheme();
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.25,
        color: scheme.onSurface,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w300,
        color: scheme.onSurface,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface.withOpacity(0.85),
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface.withOpacity(0.75),
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface.withOpacity(0.55),
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: scheme.onSurface.withOpacity(0.7),
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: scheme.onSurface.withOpacity(0.5),
      ),
    );
  }

  // ── Glassmorphism Decoration ───────────────────────────────────────────────
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    double opacity = 0.12,
    Color? tintColor,
    double borderWidth = 0.5,
    bool showShadow = false,
  }) {
    final tint = tintColor ?? Colors.white;
    return BoxDecoration(
      color: tint.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: tint.withOpacity(0.2),
        width: borderWidth,
      ),
      boxShadow: showShadow
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: tint.withOpacity(0.05),
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
