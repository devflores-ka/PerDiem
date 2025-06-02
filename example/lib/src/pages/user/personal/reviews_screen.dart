import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/review_service.dart';

class ReviewsScreen extends StatefulWidget {
  final String userId;
  final UserRating userRating;

  const ReviewsScreen({
    super.key,
    required this.userId,
    required this.userRating,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _isLoading = false;
  late UserRating _userRating;

  @override
  void initState() {
    super.initState();
    _userRating = widget.userRating;
  }

  Future<void> _refreshReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedRating = await ReviewService.getUserRatingOptimized(widget.userId);
      setState(() {
        _userRating = updatedRating;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al actualizar reseñas: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar reseñas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reseñas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReviews,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userRating.totalReviews == 0
          ? _buildEmptyState()
          : Column(
        children: [
          // Header con estadísticas
          _buildStatsHeader(),
          // Lista de reseñas
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _userRating.reviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final review = _userRating.reviews[index];
                return _buildReviewCard(review);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Calificación',
                '${_userRating.averageRating.toStringAsFixed(1)}',
                Icons.star,
                Colors.amber,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.blue.shade300,
              ),
              _buildStatItem(
                'Total Reseñas',
                '${_userRating.totalReviews}',
                Icons.comment,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barra de estrellas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Icon(
                index < _userRating.averageRating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 24,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.comment_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes reseñas aún',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las reseñas de tus clientes aparecerán aquí una vez que completes tus primeros trabajos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final dateFormat = DateFormat('d MMMM yyyy', 'es_CL');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con usuario y calificación
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: review.reviewerData?['imageUrl'] != null
                      ? NetworkImage(review.reviewerData!['imageUrl'])
                      : null,
                  child: review.reviewerData?['imageUrl'] == null
                      ? const Icon(Icons.person, size: 25)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${review.reviewerData?['firstName'] ?? 'Usuario'} ${review.reviewerData?['lastName'] ?? ''}'.trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(review.createdAt.toLocal()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        '${review.rating}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Comentario
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  review.comment,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}