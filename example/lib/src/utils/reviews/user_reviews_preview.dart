// Archivo: lib/widgets/reviews/user_reviews_preview.dart
import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import 'all_user_reviews_page.dart';
import 'review_item.dart';

class UserReviewsPreview extends StatelessWidget {
  final String userId;
  final String userName;

  const UserReviewsPreview({
    super.key,
    required this.userId,
    this.userName = 'Usuario',
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Review>>(
    future: ReviewService.getUserReviews(userId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
        return const SizedBox.shrink();
      }

      final reviews = snapshot.data!;
      // Mostrar solo las 3 reseñas más recientes
      final previewReviews = reviews.length > 3 ? reviews.sublist(0, 3) : reviews;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              'Reseñas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...previewReviews.map((review) => ReviewItem(review: review)),
          // En user_reviews_preview.dart, actualiza el botón "Ver todas las reseñas"
          if (reviews.length > 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AllUserReviewsPage(
                        userId: userId,
                        userName: userName,
                      ),
                    ),
                  );
                },
                child: Text('Ver todas las ${reviews.length} reseñas'),
              ),
            ),
        ],
      );
    },
  );
}