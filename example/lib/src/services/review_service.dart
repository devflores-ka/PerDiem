// Archivo: lib/services/review_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Review {
  final String id;
  final String reviewerId;
  final String reviewedId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final Map<String, dynamic>? reviewerData;
  final String? proposalId; // Agregado para rastrear propuestas

  Review({
    required this.id,
    required this.reviewerId,
    required this.reviewedId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.reviewerData,
    this.proposalId,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'].toString(),
    reviewerId: json['reviewer_id'],
    reviewedId: json['reviewed_id'],
    rating: json['rating'],
    comment: json['comment'] ?? '',
    createdAt: DateTime.parse(json['created_at']),
    reviewerData: json['reviewer_data'],
    proposalId: json['proposal_id'], // Agregado
  );
}

class UserRating {
  final String userId;
  final double averageRating;
  final int totalReviews;
  final List<Review> reviews;

  UserRating({
    required this.userId,
    required this.averageRating,
    required this.totalReviews,
    required this.reviews,
  });
}

class ReviewService {
  static final _supabase = Supabase.instance.client;

  // Crear una nueva reseña con proposalId
  static Future<Review> createReview({
    required String reviewedId,
    required int rating,
    required String comment,
    String? proposalId, // Agregado para rastrear la propuesta
  }) async {
    final currentUser = _supabase.auth.currentUser;

    // Verificación de null safety
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    final currentUserId = currentUser.id;

    try {
      final insertData = {
        'reviewer_id': currentUserId,
        'reviewed_id': reviewedId,
        'rating': rating,
        'comment': comment,
      };

      // Solo agregar proposal_id si se proporciona
      if (proposalId != null) {
        insertData['proposal_id'] = proposalId;
      }

      final response = await _supabase
          .schema('jobs')
          .from('reviews')
          .insert(insertData)
          .select()
          .single();

      return Review.fromJson(response);
    } catch (e) {
      debugPrint('Error al crear reseña: $e');
      throw Exception('No se pudo crear la reseña: $e');
    }
  }

  // Obtener todas las reseñas de un usuario específico
  static Future<List<Review>> getUserReviews(String userId) async {
    try {
      // Obtener las reseñas
      final response = await _supabase
          .schema('jobs')
          .from('reviews')
          .select()
          .eq('reviewed_id', userId)
          .order('created_at', ascending: false);

      // Convertir a lista de Review
      final reviews = (response as List).map((item) => Review.fromJson(item)).toList();

      // Para cada reseña, obtener datos del evaluador
      for (int i = 0; i < reviews.length; i++) {
        try {
          final reviewerData = await _supabase
              .schema('chats')
              .from('users')
              .select('id, firstName, lastName, imageUrl')
              .eq('id', reviews[i].reviewerId)
              .single();

          // Crear una nueva instancia con los datos del evaluador
          reviews[i] = Review(
            id: reviews[i].id,
            reviewerId: reviews[i].reviewerId,
            reviewedId: reviews[i].reviewedId,
            rating: reviews[i].rating,
            comment: reviews[i].comment,
            createdAt: reviews[i].createdAt,
            proposalId: reviews[i].proposalId,
            reviewerData: reviewerData,
          );
        } catch (e) {
          debugPrint('Error al obtener datos del evaluador ${reviews[i].reviewerId}: $e');
          // Continuamos con la siguiente reseña si hay error
        }
      }

      return reviews;
    } catch (e) {
      debugPrint('Error al obtener reseñas: $e');
      throw Exception('No se pudieron obtener las reseñas: $e');
    }
  }

  // Calcular la calificación promedio de un usuario de forma eficiente
  static Future<UserRating> getUserRating(String userId) async {
    try {
      // Obtener todas las reseñas del usuario
      final reviews = await getUserReviews(userId);

      // Si no hay reseñas, devolver calificación por defecto
      if (reviews.isEmpty) {
        return UserRating(
          userId: userId,
          averageRating: 0.0,
          totalReviews: 0,
          reviews: [],
        );
      }

      // Calcular la calificación promedio
      final totalRating = reviews.fold(0, (sum, review) => sum + review.rating);
      final averageRating = totalRating / reviews.length;

      return UserRating(
        userId: userId,
        averageRating: averageRating,
        totalReviews: reviews.length,
        reviews: reviews,
      );
    } catch (e) {
      debugPrint('Error al calcular calificación: $e');
      throw Exception('No se pudo calcular la calificación: $e');
    }
  }

  // Método optimizado que calcula el promedio directamente en la base de datos
  static Future<UserRating> getUserRatingOptimized(String userId) async {
    debugPrint('🔍 ReviewService: Obteniendo calificación para userId: $userId');

    try {
      // Calcular promedio y contar reseñas directamente en la base de datos
      final averageResponse = await _supabase
          .schema('jobs')
          .rpc('calculate_user_rating', params: {'user_id': userId});

      debugPrint('📊 ReviewService: Respuesta de RPC calculate_user_rating: $averageResponse');

      // Extraer valores de la respuesta con verificación de nulos
      double averageRating = 0.0;
      int totalReviews = 0;

      if (averageResponse != null) {
        // Intentar extraer avg_rating como double
        if (averageResponse['avg_rating'] != null) {
          if (averageResponse['avg_rating'] is double) {
            averageRating = averageResponse['avg_rating'];
          } else if (averageResponse['avg_rating'] is int) {
            averageRating = (averageResponse['avg_rating'] as int).toDouble();
          } else {
            try {
              averageRating = double.parse(averageResponse['avg_rating'].toString());
            } catch (e) {
              debugPrint('⚠️ Error convirtiendo avg_rating a double: $e');
            }
          }
        }

        // Intentar extraer review_count como int
        if (averageResponse['review_count'] != null) {
          if (averageResponse['review_count'] is int) {
            totalReviews = averageResponse['review_count'];
          } else {
            try {
              totalReviews = int.parse(averageResponse['review_count'].toString());
            } catch (e) {
              debugPrint('⚠️ Error convirtiendo review_count a int: $e');
            }
          }
        }
      }

      debugPrint('⭐ ReviewService: Calificación promedio: $averageRating, Total reseñas: $totalReviews');

      // Si no hay reseñas, no obtenemos la lista completa
      if (totalReviews == 0) {
        debugPrint('ℹ️ ReviewService: No hay reseñas para este usuario');
        return UserRating(
          userId: userId,
          averageRating: 0.0,
          totalReviews: 0,
          reviews: [],
        );
      }

      // Obtener las reseñas para mostrar detalles
      debugPrint('🔍 ReviewService: Obteniendo lista de reseñas para el usuario');
      final reviews = await getUserReviews(userId);
      debugPrint('📝 ReviewService: Obtenidas ${reviews.length} reseñas');

      debugPrint('✅ ReviewService: Calificación y reseñas obtenidas correctamente');
      return UserRating(
        userId: userId,
        averageRating: averageRating,
        totalReviews: totalReviews,
        reviews: reviews,
      );
    } catch (e) {
      debugPrint('❌ Error en método optimizado: $e');
      debugPrint('📜 Stack trace: ${StackTrace.current}');

      // Si falla la función RPC, intentar con el método normal
      debugPrint('🔄 Intentando método alternativo getUserRating...');
      try {
        return await getUserRating(userId);
      } catch (fallbackError) {
        debugPrint('❌ Error en método alternativo: $fallbackError');
        // Si ambos métodos fallan, devolver un objeto vacío
        return UserRating(
          userId: userId,
          averageRating: 0.0,
          totalReviews: 0,
          reviews: [],
        );
      }
    }
  }

  // CORREGIDO: Verificar si el usuario actual ya ha calificado a otro usuario para una PROPUESTA específica
  static Future<bool> hasReviewedUser(String reviewedId, String proposalId) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      // Verificación de null safety
      if (currentUser == null) {
        debugPrint('⚠️ hasReviewedUser: Usuario no autenticado');
        return false;
      }

      final currentUserId = currentUser.id;

      debugPrint('🔍 hasReviewedUser: Verificando si $currentUserId ya reseñó a $reviewedId para propuesta $proposalId');

      final response = await _supabase
          .schema('jobs')
          .from('reviews')
          .select('id')
          .eq('reviewer_id', currentUserId)
          .eq('reviewed_id', reviewedId)
          .eq('proposal_id', proposalId); // ✅ CRÍTICO: Verificar por propuesta específica

      debugPrint('📊 hasReviewedUser: Encontradas ${response.length} reseñas para esta propuesta específica');

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error al verificar si ya ha calificado: $e');
      return false; // En caso de error, asumimos que no ha reseñado
    }
  }

  // Obtener reseñas donde el usuario actual es el evaluador
  static Future<List<Review>> getReviewsMadeByUser() async {
    try {
      final currentUser = _supabase.auth.currentUser;

      // Verificación de null safety
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final currentUserId = currentUser.id;

      final response = await _supabase
          .schema('jobs')
          .from('reviews')
          .select()
          .eq('reviewer_id', currentUserId)
          .order('created_at', ascending: false);

      return (response as List).map((item) => Review.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error al obtener reseñas hechas por el usuario: $e');
      throw Exception('No se pudieron obtener las reseñas: $e');
    }
  }
}