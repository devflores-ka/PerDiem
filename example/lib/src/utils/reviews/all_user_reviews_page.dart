// Archivo: lib/pages/reviews/all_user_reviews_page.dart
import 'package:flutter/material.dart';

import '../../services/review_service.dart';
import 'review_item.dart';

class AllUserReviewsPage extends StatelessWidget {
  final String userId;
  final String userName;

  const AllUserReviewsPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Reseñas de $userName'),
    ),
    body: FutureBuilder<UserRating>(
      future: ReviewService.getUserRatingOptimized(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar reseñas: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.reviews.isEmpty) {
          return const Center(
            child: Text('No hay reseñas disponibles'),
          );
        }

        final userRating = snapshot.data!;
        final reviews = userRating.reviews;

        return Column(
          children: [
            // Resumen de calificaciones
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  // Calificación grande
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 24),
                            const SizedBox(width: 4),
                            Text(
                              userRating.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${userRating.totalReviews} ${userRating.totalReviews == 1 ? "reseña" : "reseñas"}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Distribución de estrellas (simplificada)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$userName tiene una calificación promedio de ${userRating.averageRating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Basado en ${userRating.totalReviews} ${userRating.totalReviews == 1 ? "cliente" : "clientes"}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de reseñas
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: reviews.length,
                itemBuilder: (context, index) => ReviewItem(review: reviews[index]),
              ),
            ),
          ],
        );
      },
    ),
  );
}