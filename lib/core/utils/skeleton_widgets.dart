import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton Screens — used during loading in place of circular indicators
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonContainer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonContainer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor:
          Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SongTileSkeleton extends StatelessWidget {
  const SongTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SkeletonContainer(width: 52, height: 52, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonContainer(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 6,
                ),
                const SizedBox(height: 8),
                SkeletonContainer(width: 120, height: 11, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SkeletonContainer(width: 32, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}

class SongListSkeleton extends StatelessWidget {
  final int count;
  const SongListSkeleton({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => SongTileSkeleton()
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn()
            .slideX(begin: 0.05),
      ),
    );
  }
}

class CardSkeleton extends StatelessWidget {
  final double width;
  final double height;
  const CardSkeleton(
      {super.key, this.width = 160, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonContainer(
            width: width, height: width, borderRadius: 14),
        const SizedBox(height: 8),
        SkeletonContainer(width: width * 0.8, height: 13, borderRadius: 6),
        const SizedBox(height: 5),
        SkeletonContainer(width: width * 0.5, height: 11, borderRadius: 6),
      ],
    );
  }
}

class HorizontalCardListSkeleton extends StatelessWidget {
  final int count;
  final double cardWidth;
  const HorizontalCardListSkeleton(
      {super.key, this.count = 5, this.cardWidth = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (ctx, i) => CardSkeleton(width: cardWidth)
            .animate(delay: Duration(milliseconds: i * 80))
            .fadeIn()
            .slideX(begin: 0.1),
      ),
    );
  }
}
