import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'app_theme.dart';

class AmbientBackground extends StatefulWidget {
  final String? imageUrl;
  final Widget child;
  final double overlayOpacity;
  final Color? dominantColor;

  const AmbientBackground({
    super.key,
    this.imageUrl,
    required this.child,
    this.overlayOpacity = 0.3,
    this.dominantColor,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> {
  Color _dominantColor = FlowyColors.brandSeed;

  @override
  void initState() {
    super.initState();
    _updateColor();
  }

  @override
  void didUpdateWidget(AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _updateColor();
    }
  }

  Future<void> _updateColor() async {
    final color = await DynamicPaletteService().getDominantColor(widget.imageUrl);
    if (color != null && mounted) {
      setState(() => _dominantColor = color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.dominantColor ?? _dominantColor;
    
    // Elegant color palette derived from dominant color
    final hsl = HSLColor.fromColor(effectiveColor);
    
    // Deep, vibrant background colors
    final color1 = hsl.withLightness((hsl.lightness * 0.4).clamp(0.05, 0.2)).toColor();
    final color2 = hsl.withSaturation((hsl.saturation * 0.8).clamp(0.2, 0.7))
                      .withLightness((hsl.lightness * 0.3).clamp(0.05, 0.15)).toColor();
    final color3 = FlowyColors.surface;
    final color4 = hsl.withHue((hsl.hue + 45) % 360)
                      .withLightness((hsl.lightness * 0.4).clamp(0.05, 0.2)).toColor();

    return Stack(
      children: [
        // ── Mesh Gradient Layer ──────────────────────────────────────
        Positioned.fill(
          child: AnimatedMeshGradient(
            colors: [color1, color2, color3, color4],
            options: AnimatedMeshGradientOptions(
              speed: 1.5,
              amplitude: 30,
            ),
          ),
        ),
        
        // ── Vignette & Noise Overlay ──────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),

        // ── Main Content ─────────────────────────────────────────────
        widget.child,
      ],
    );
  }
}
