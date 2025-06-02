import 'package:flutter/material.dart';

// Componente reutilizable para mostrar la tarjeta de oferta compartida internamente
class OfertaCompartidaInterna extends StatelessWidget {
  final String imagenUrl;
  final String nombreOferta;
  final String descripcion;
  final int presupuesto;
  final String offerId;
  final VoidCallback onTap;

  const OfertaCompartidaInterna({
    super.key,
    required this.imagenUrl,
    required this.nombreOferta,
    required this.descripcion,
    required this.presupuesto,
    required this.offerId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            // Imagen de la oferta
            Image.network(
              imagenUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error, size: 40),
                );
              },
            ),

            // Información de la oferta
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre de la oferta
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

                  // Descripción corta
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 8),

                  // Presupuesto
                  Text(
                    '\$${presupuesto.toString()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Badge "Oferta compartida"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share, size: 14, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Oferta compartida',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para manejar la visualización de la tarjeta compartida en un chat
class MensajeOfertaCompartida extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final Function(String) onOfertaPressed;

  const MensajeOfertaCompartida({
    super.key,
    required this.metadata,
    required this.onOfertaPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Extraer datos del mensaje
    final offerId = metadata['offer_id'] as String? ?? '';
    final nombreOferta = metadata['offer_name'] as String? ?? 'Oferta';
    final imagenUrl = metadata['image_url'] as String? ?? 'https://via.placeholder.com/400';
    final descripcion = metadata['description'] as String? ?? 'Sin descripción';
    final presupuesto = metadata['budget'] as int? ?? 0;

    return OfertaCompartidaInterna(
      imagenUrl: imagenUrl,
      nombreOferta: nombreOferta,
      descripcion: descripcion,
      presupuesto: presupuesto,
      offerId: offerId,
      onTap: () => onOfertaPressed(offerId),
    );
  }
}