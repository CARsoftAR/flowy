import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'app_theme.dart';

class AmbientBackground extends StatelessWidget {
  final String? imageUrl;
  final Widget child;
  final double overlayOpacity;

  const AmbientBackground({
    super.key,
    this.imageUrl,
    required this.child,
    this.overlayOpacity = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
      future: DynamicPaletteService().getDominantColor(imageUrl),
      builder: (context, snapshot) {
        final dominantColor = snapshot.data ?? FlowyColors.brandSeed;
        
        // Generate a few variations for the mesh
        final hapticColor = HSLColor.fromColor(dominantColor);
        final color1 = hapticColor.withLightness(0.15).toColor();
        final color2 = hapticColor.withLightness(0.1).withSaturation(0.4).toColor();
        final color3 = FlowyColors.surface;
        final color4 = hapticColor.withHue((hapticColor.hue + 30) % 360).withLightness(0.12).toColor();

        return Stack(
          children: [
            // Mesh Gradient layer
            Positioned.fill(
              child: AnimatedMeshGradient(
                colors: [color1, color2, color3, color4],
                options: AnimatedMeshGradientOptions(
                  speed: 2,
                ),
              ),
            ),
            
            // Subtle overlay to ensure readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: FlowyColors.surface.withOpacity(overlayOpacity),
                ),
              ),
            ),


            // The content
            child,
          ],
        );
      },
    );
  }
}
