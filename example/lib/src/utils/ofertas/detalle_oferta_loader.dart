// Archivo: lib/pages/ofertas/detalle_oferta_loader.dart
import 'package:flutter/material.dart';
import '../../services/offers_service.dart';
import '../../services/review_service.dart';
import '../../utils/ofertas/detalle_oferta.dart'; // Asegúrate que la ruta sea correcta

class DetalleOfertaLoader extends StatelessWidget {
  final String offerId;
  final OffersService _offersService = OffersService();

  DetalleOfertaLoader({super.key, required this.offerId});

  // Función para procesar el presupuesto y manejar formatos como "2.5k"
  double procesarPresupuesto(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      String processed = amount.replaceAll('\$', '').replaceAll(' ', '');
      if (processed.toLowerCase().contains('k')) {
        processed = processed.toLowerCase().replaceAll('k', '');
        try {
          return double.parse(processed) * 1000;
        } catch (e) {
          debugPrint('⚠️ Error procesando valor con k: $e');
          return 0.0;
        }
      }
      try {
        return double.parse(processed);
      } catch (e) {
        debugPrint('⚠️ Error procesando valor numérico: $e');
        return 0.0;
      }
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 DetalleOfertaLoader: Cargando oferta ID: $offerId');

    return FutureBuilder<Map<String, dynamic>?>(
      future: _offersService.getOfferById(offerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          debugPrint('❌ Error cargando oferta: ${snapshot.error}');
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('No se pudo cargar la oferta')),
          );
        }

        final data = snapshot.data!;
        final user = data['user'] as Map<String, dynamic>?;
        
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Datos de usuario no disponibles')),
          );
        }

        // Recuperamos el ID del usuario (que ya lo tenías aquí)
        final userId = data['user_id'] as String?;

        return FutureBuilder<UserRating>(
            future: ReviewService.getUserRatingOptimized(userId ?? ''),
            builder: (context, ratingSnapshot) {
              double calificacion = 0.0;
              String numResenas = "0";
              bool mostrarCalificacion = false;

              if (ratingSnapshot.hasData) {
                calificacion = ratingSnapshot.data!.averageRating;
                numResenas = ratingSnapshot.data!.totalReviews.toString();
                mostrarCalificacion = ratingSnapshot.data!.totalReviews > 0;
              }

              final presupuesto = procesarPresupuesto(data['amount']);
              
              final String firstName = user['firstName'] ?? '';
              final String lastName = user['lastName'] ?? '';
              final String nombreCompleto = [firstName, lastName]
                  .where((part) => part.isNotEmpty)
                  .join(' ');

              return DetalleOferta(
                imagenUrl: data['image_url'] ?? 'https://via.placeholder.com/400',
                descripcion: data['description'] ?? 'Sin descripción',
                presupuesto: presupuesto,
                nombreUsuario: nombreCompleto.isNotEmpty ? nombreCompleto : 'Usuario',
                avatarUrl: user['imageUrl'] ?? 'https://via.placeholder.com/100',
                calificacion: calificacion,
                numResenas: numResenas,
                mostrarCalificacion: mostrarCalificacion,
                latitud: (data['latitud'] is num) ? (data['latitud'] as num).toDouble() : 0.0,
                longitud: (data['longitud'] is num) ? (data['longitud'] as num).toDouble() : 0.0,
                offerId: data['id'].toString(), // Aseguramos que sea String
                offerName: data['name'] ?? 'Oferta sin título',
                
                // ✅ AQUÍ ESTÁ EL CAMBIO IMPORTANTE:
                userId: userId ?? '', // Pasamos el ID que recuperamos arriba
              );
            }
        );
      },
    );
  }
}