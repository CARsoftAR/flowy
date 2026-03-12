import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class SkeletonShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: FlowyColors.surfaceContainer,
      highlightColor: FlowyColors.surfaceVariant.withOpacity(0.5),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.circle 
              ? null 
              : BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Circular skeleton, perfect for avatars or small icons.
  static Widget circle({required double size}) {
    return SkeletonShimmer(
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }

  /// Rectangular skeleton for cards or text blocks.
  static Widget rect({
    required double width,
    required double height,
    double borderRadius = 12,
  }) {
    return SkeletonShimmer(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}
