// Archivo: lib/widgets/reviews/review_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/review_service.dart';

class ReviewItem extends StatelessWidget {
  final Review review;

  const ReviewItem({
    super.key,
    required this.review,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar del revisor
              if (review.reviewerData != null && review.reviewerData!['avatar_url'] != null)
                CircleAvatar(
                  backgroundImage: NetworkImage(review.reviewerData!['avatar_url']),
                  radius: 16,
                  onBackgroundImageError: (_, __) => const Icon(Icons.person),
                )
              else
                const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 20),
                ),
              const SizedBox(width: 8),

              // Nombre del revisor
              Text(
                review.reviewerData != null ?
                '${review.reviewerData!['first_name'] ?? ''} ${review.reviewerData!['last_name'] ?? ''}' :
                'Usuario',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),

              // Calificación
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  Text('${review.rating}'),
                ],
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment),
          ],
          const SizedBox(height: 4),
          Text(
            DateFormat('dd/MM/yyyy').format(review.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    ),
  );
}