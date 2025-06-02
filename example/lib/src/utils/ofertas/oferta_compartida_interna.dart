// Archivo: lib/widgets/ofertas/oferta_compartida_interna.dart
import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import '../../widgets/rating_display.dart';
import 'detalle_oferta_loader.dart';

class OfertaCompartidaInterna extends StatelessWidget {
  final String imagenUrl;
  final String nombreOferta;
  final String descripcion;
  final double presupuesto;
  final String offerId;
  final String userId; // Añadir esta propiedad
  final String userName; // Añadir esta propiedad opcional

  const OfertaCompartidaInterna({
    super.key,
    required this.imagenUrl,
    required this.nombreOferta,
    required this.descripcion,
    required this.presupuesto,
    required this.offerId,
    required this.userId, // Requerido para buscar calificaciones
    this.userName = '', // Opcional si ya tienes el nombre
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      // Navegar a la página de detalles de la oferta cuando se presiona
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetalleOfertaLoader(offerId: offerId),
        ),
      );
    },
    child: Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.network(
            imagenUrl,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image_not_supported)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreOferta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${presupuesto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                // Añadir calificación del usuario
                FutureBuilder<UserRating>(
                  future: ReviewService.getUserRatingOptimized(userId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.totalReviews > 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: RatingDisplay(
                          rating: snapshot.data!.averageRating,
                          reviewCount: snapshot.data!.totalReviews,
                        ),
                      );
                    }
                    return const SizedBox.shrink(); // No mostrar nada si no hay datos
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    ),
  );
}