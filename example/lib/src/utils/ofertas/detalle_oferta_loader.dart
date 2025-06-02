// Archivo: lib/pages/ofertas/detalle_oferta_loader.dart
import 'package:flutter/material.dart';
import '../../services/offers_service.dart';
import '../../services/review_service.dart';
import 'detalle_oferta.dart';

class DetalleOfertaLoader extends StatelessWidget {
  final String offerId;
  final OffersService _offersService = OffersService();

  DetalleOfertaLoader({super.key, required this.offerId});

  // Función para procesar el presupuesto y manejar formatos como "2.5k"
  double procesarPresupuesto(dynamic amount) {
    if (amount == null) return 0.0;

    // Si ya es double, devolverlo directamente
    if (amount is double) return amount;

    // Si es int, convertirlo a double
    if (amount is int) return amount.toDouble();

    // Si es string, procesarlo
    if (amount is String) {
      // Remover cualquier símbolo de moneda y espacios
      String processed = amount.replaceAll('\$', '').replaceAll(' ', '');

      // Manejar notación 'k' (miles)
      if (processed.toLowerCase().contains('k')) {
        processed = processed.toLowerCase().replaceAll('k', '');
        try {
          return double.parse(processed) * 1000;
        } catch (e) {
          debugPrint('⚠️ Error procesando valor con k: $e');
          return 0.0;
        }
      }

      // Intentar convertir directamente
      try {
        return double.parse(processed);
      } catch (e) {
        debugPrint('⚠️ Error procesando valor numérico: $e');
        return 0.0;
      }
    }

    return 0.0; // Valor predeterminado si no se puede procesar
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 DetalleOfertaLoader: Cargando oferta ID: $offerId');

    return FutureBuilder<Map<String, dynamic>?>(
      // Usar el método getOfferById del servicio de ofertas
      future: _offersService.getOfferById(offerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ DetalleOfertaLoader: Esperando datos de la oferta...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          debugPrint('❌ DetalleOfertaLoader: Error al cargar oferta - ${snapshot.error}');
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('No se pudo cargar la oferta')),
          );
        }

        final data = snapshot.data!;
        debugPrint('📊 DetalleOfertaLoader: Datos de oferta recibidos: ${data.keys}');

        final user = data['user'] as Map<String, dynamic>?;
        if (user == null) {
          debugPrint('⚠️ DetalleOfertaLoader: Datos de usuario no disponibles');
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Datos de usuario no disponibles')),
          );
        }

        final userId = data['user_id'] as String?;
        debugPrint('👤 DetalleOfertaLoader: Datos de usuario obtenidos para: ${user['firstName']} ${user['lastName']}');
        debugPrint('🔍 DetalleOfertaLoader: Obteniendo reputación para userId: $userId');

        // Cargar las calificaciones del usuario
        return FutureBuilder<UserRating>(
            future: ReviewService.getUserRatingOptimized(userId ?? ''),
            builder: (context, ratingSnapshot) {
              // Valores predeterminados (no mostrar si no hay datos)
              double calificacion = 0.0;
              String numResenas = "0";
              bool mostrarCalificacion = false;

              // Log del estado de la carga de calificaciones
              debugPrint('📊 DetalleOfertaLoader: Estado de carga de reputación: ${ratingSnapshot.connectionState}');

              // Si se completó la carga, verificar si hay datos
              if (ratingSnapshot.hasData) {
                calificacion = ratingSnapshot.data!.averageRating;
                numResenas = ratingSnapshot.data!.totalReviews.toString();
                debugPrint('⭐ DetalleOfertaLoader: Calificación: $calificacion, Reseñas: $numResenas');

                // Solo mostrar calificación si hay reseñas
                mostrarCalificacion = ratingSnapshot.data!.totalReviews > 0;
                debugPrint('👁️ DetalleOfertaLoader: ¿Mostrar calificación? $mostrarCalificacion');
              } else if (ratingSnapshot.hasError) {
                debugPrint('❌ DetalleOfertaLoader: Error al cargar reputación - ${ratingSnapshot.error}');
              }

              // Extraer datos correctamente del resultado de la consulta
              final presupuesto = procesarPresupuesto(data['amount']);
              debugPrint('💰 DetalleOfertaLoader: Presupuesto procesado: $presupuesto');

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
                mostrarCalificacion: mostrarCalificacion, // Pasar la bandera
                latitud: (data['latitud'] is num) ? (data['latitud'] as num).toDouble() : 0.0,
                longitud: (data['longitud'] is num) ? (data['longitud'] as num).toDouble() : 0.0,
                offerId: data['id'],
                offerName: data['name'] ?? 'Oferta sin título',
              );
            }
        );
      },
    );
  }
}