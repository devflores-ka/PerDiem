// Archivo: lib/widgets/rating_display.dart
import 'package:flutter/material.dart';

class RatingDisplay extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double iconSize;
  final bool showEmpty;

  const RatingDisplay({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.iconSize = 18,
    this.showEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    // No mostrar si no hay reseñas y showEmpty es falso
    if (reviewCount == 0 && !showEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(Icons.star, color: Colors.amber, size: iconSize),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviewCount ${reviewCount == 1 ? "reseña" : "reseñas"})',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}