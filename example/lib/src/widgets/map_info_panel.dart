// Archivo: lib/widgets/map_info_panel.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapInfoPanel extends StatelessWidget {
  final String selectedCategory;
  final String currentSector;
  final LatLng currentPosition;
  final int workerCount;

  const MapInfoPanel({
    super.key,
    required this.selectedCategory,
    required this.currentSector,
    required this.currentPosition,
    required this.workerCount,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(8.0),
    child: Column(
      children: [
        Text(
          'Categoría: $selectedCategory',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Sector Actual: $currentSector',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Coordenadas: ${currentPosition.latitude.toStringAsFixed(4)}, ${currentPosition.longitude.toStringAsFixed(4)}',
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        Text(
          'Trabajadores cercanos: $workerCount',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}