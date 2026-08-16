import 'package:flutter/material.dart';

import '../models/spot.dart';
import '../theme/app_theme.dart';

class SpotCard extends StatelessWidget {
  const SpotCard({
    super.key,
    required this.spot,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Spot spot;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _categoryColor(spot.category).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  spot.category.icon,
                  color: _categoryColor(spot.category),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            spot.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${spot.distanceMiles.toStringAsFixed(1)} mi',
                          style: const TextStyle(
                            color: SuppupColors.forest,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _RatingLine(spot: spot),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final badge in spot.badges)
                          _MiniBadge(label: badge),
                        if (spot.isPreview) const _MiniBadge(label: 'Preview'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? SuppupColors.coral : SuppupColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    if (spot.communityRating == null) {
      return const Row(
        children: [
          Icon(Icons.star_outline_rounded, size: 18, color: SuppupColors.coral),
          SizedBox(width: 4),
          Text(
            'Be the first to rate it',
            style: TextStyle(
              color: SuppupColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 18, color: SuppupColors.sunshine),
        const SizedBox(width: 4),
        Text(
          spot.communityRating!.toStringAsFixed(1),
          style: const TextStyle(
            color: SuppupColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${spot.ratingCount} Suppup ratings)',
          style: const TextStyle(color: SuppupColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: SuppupColors.mint.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: SuppupColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _categoryColor(SpotCategory category) => switch (category) {
  SpotCategory.walks => SuppupColors.forest,
  SpotCategory.dogParks => SuppupColors.coral,
  SpotCategory.treats => const Color(0xFFD58B1C),
};
