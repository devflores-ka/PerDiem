// Archivo: lib/widgets/ofertas/detalle_oferta.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/rating_display.dart';
import '../reviews/user_reviews_preview.dart';
import 'contact_button.dart';

// Formato de moneda
final numberFormat = NumberFormat.currency(
  locale: 'es_CL',
  symbol: '\$',
  decimalDigits: 0,
);

class DetalleOferta extends StatelessWidget {
  final String imagenUrl;
  final String descripcion;
  final double presupuesto;
  final String nombreUsuario;
  final String avatarUrl;
  final double calificacion;
  final String numResenas;
  final bool mostrarCalificacion; // Nueva propiedad
  final double latitud;
  final double longitud;
  final String offerId;
  final String offerName;

  const DetalleOferta({
    super.key,
    required this.imagenUrl,
    required this.descripcion,
    required this.presupuesto,
    required this.nombreUsuario,
    required this.avatarUrl,
    required this.calificacion,
    required this.numResenas,
    this.mostrarCalificacion = false, // Por defecto no mostrar
    required this.latitud,
    required this.longitud,
    required this.offerId,
    required this.offerName,
  });

  // Método para obtener el userId desde el offerId de manera segura
  String getUserIdFromOfferId() {
    try {
      final parts = offerId.split('-');
      if (parts.isNotEmpty) {
        debugPrint('🆔 DetalleOferta: userId extraído del offerId: ${parts.first}');
        return parts.first;
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo userId desde offerId: $e');
    }

    // Si no podemos extraer el ID del usuario de la oferta, intentar usar el offerId directamente
    debugPrint('⚠️ DetalleOferta: Usando offerId completo como userId: $offerId');
    return offerId;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalles del Servicio'),
    ),
    backgroundColor: Colors.white,
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Perfil del usuario
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(avatarUrl),
                  radius: 25,
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreUsuario,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      // Solo mostrar calificación si hay datos
                      if (mostrarCalificacion)
                        RatingDisplay(
                          rating: calificacion,
                          reviewCount: int.tryParse(numResenas) ?? 0,
                          iconSize: 18,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Imagen de la oferta
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imagenUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.image_not_supported)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Descripción
            Text(
              descripcion,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 16),

            // Presupuesto
            Text(
              '${numberFormat.format(presupuesto)} CLP',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 16),

            // Mapa con la ubicación
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(latitud, longitud),
                    minZoom: 5,
                    maxZoom: 18,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none, // Deshabilita interacción
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                      additionalOptions: {
                        'accessToken': 'pk.eyJ1IjoiZGV2ZmxvcmVzIiwiYSI6ImNtOHFnNDN2aTBreHMyanE0ZHpnYjM2OXYifQ.e1I0xrOXkJOXl_R0Vx9gfg',
                        'id': 'mapbox/streets-v12',
                      },
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(latitud, longitud),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón de contactar
            ContactButton(
              offerId: offerId,
              offerName: offerName,
            ),

            // Widget con las últimas reseñas del usuario - solo mostrar si hay calificaciones
            if (mostrarCalificacion) ...[
              const SizedBox(height: 24),
              const Text(
                'Reseñas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              UserReviewsPreview(
                userId: getUserIdFromOfferId(),
                userName: nombreUsuario,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}