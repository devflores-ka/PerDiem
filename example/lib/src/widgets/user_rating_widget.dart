// lib/widgets/user_rating_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/l10n/generated/app_localizations.dart';

import '../services/review_service.dart';

class UserRatingWidget extends StatelessWidget {
  final String userId;
  final bool showDetails;
  final double size;
  final Color? color;
  final bool showCount;

  const UserRatingWidget({
    super.key,
    required this.userId,
    this.showDetails = false,
    this.size = 20,
    this.color,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) { 
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<UserRating>(
      future: ReviewService.getUserRatingOptimized(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              Icon(Icons.star, color: Colors.grey[300], size: size),
              const SizedBox(width: 4),
              Text(
                l10n.loading,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: size * 0.8,
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: size),
              const SizedBox(width: 4),
              Text(
                l10n.error,
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: size * 0.8,
                ),
              ),
            ],
          );
        }

        // Si no hay datos o si el usuario no tiene reseñas
        if (!snapshot.hasData || snapshot.data!.totalReviews == 0) {
          return Row(
            children: [
              Icon(Icons.star_border, color: Colors.grey, size: size),
              const SizedBox(width: 4),
              Text(
                l10n.withoutReview,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: size * 0.8,
                ),
              ),
            ],
          );
        }

        final rating = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: color ?? Colors.amber,
                  size: size,
                ),
                const SizedBox(width: 4),
                Text(
                  rating.averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.8,
                    color: color ?? Colors.black,
                  ),
                ),
                if (showCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${rating.totalReviews})',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: size * 0.7,
                    ),
                  ),
                ],
              ],
            ),

            // Mostrar detalles de las reseñas si se solicita
            if (showDetails && rating.reviews.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.reviews} (${rating.totalReviews})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...rating.reviews.map((review) => _buildReviewItem(context, review)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReviewItem(BuildContext context, Review review) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar del evaluador
                if (review.reviewerData != null && review.reviewerData!['avatar_url'] != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(review.reviewerData!['avatar_url']),
                    radius: 20,
                  )
                else
                  const CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 20,
                    child: Icon(Icons.person, color: Colors.white),
                  ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del evaluador
                      Text(
                        review.reviewerData != null
                            ? "${review.reviewerData!['first_name'] ?? ''} ${review.reviewerData!['last_name'] ?? ''}"
                            : 'Usuario',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Fecha
                      Text(
                        dateFormat.format(review.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Estrellas
                      Row(
                        children: List.generate(5, (index) => Icon(
                            index < review.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Comentario
            if (review.comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(review.comment),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar solo las estrellas (versión simple)
class SimpleRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const SimpleRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        // Para mostrar estrellas parciales
        if (index < rating.floor()) {
          // Estrella completa
          return Icon(Icons.star, size: size, color: color);
        } else if (index < rating.ceil() && index > rating.floor()) {
          // Estrella parcial
          return Icon(Icons.star_half, size: size, color: color);
        } else {
          // Estrella vacía
          return Icon(Icons.star_border, size: size, color: color);
        }
      }),
    );
}