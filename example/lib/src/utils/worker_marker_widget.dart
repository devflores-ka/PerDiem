import 'package:flutter/material.dart';

class WorkerMarkerWidget extends StatelessWidget {
  final String avatarUrl;
  final String fullName;
  final double rating;
  final int ratingCount;

  const WorkerMarkerWidget({
    super.key,
    required this.avatarUrl,
    required this.fullName,
    required this.rating,
    required this.ratingCount,
  });

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(12),
    color: Colors.white,
    child: Container(
      constraints: const BoxConstraints(
        maxWidth: 110, // Fijamos un ancho máximo
        maxHeight: 155, // Fijamos una altura máxima
      ),
      padding: const EdgeInsets.all(6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(avatarUrl),
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 4),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Simplificamos el indicador de calificación
          Text(
            '⭐ $rating',
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}