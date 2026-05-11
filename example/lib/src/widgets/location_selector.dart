// Archivo: lib/widgets/location_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '/l10n/generated/app_localizations.dart';
import '../services/geographic_service.dart';

class LocationSelectorScreen extends StatefulWidget {
  final LatLng initialPosition;

  const LocationSelectorScreen({
    super.key,
    required this.initialPosition,
  });

  @override
  State<LocationSelectorScreen> createState() => _LocationSelectorScreenState();
}

class _LocationSelectorScreenState extends State<LocationSelectorScreen> {
  late MapController _mapController;
  late LatLng _selectedPosition;

  // Para la búsqueda
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedPosition = widget.initialPosition;
  }

  // Buscar ubicaciones por texto
  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await GeographicService.searchLocations(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en la búsqueda: $e')),
      );
    }
  }

  // Mover el mapa a una ubicación específica
  void _moveMapToLocation(LatLng location) {
    setState(() {
      _selectedPosition = location;
    });
    _mapController.move(location, 15);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.peakUbiaction),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedPosition);
            },
            child: Text(
              l10n.confirm,
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador de ubicaciones
          _buildSearchBar(),

          // Mostrar resultados de búsqueda si hay
          if (_searchResults.isNotEmpty)
            _buildSearchResults(),

          // Mapa interactivo
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.initialPosition,
                    initialZoom: 13,
                    onTap: (_, point) {
                      setState(() {
                        _selectedPosition = point;
                      });
                    },
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
                          width: 40,
                          height: 40,
                          point: _selectedPosition,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Instrucciones
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        l10n.searchUbiOrPickOne,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coordenadas
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Coordenadas: ${_selectedPosition.latitude.toStringAsFixed(6)}, ${_selectedPosition.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: l10n.searchUbi,
          hintText: l10n.searchUbiExample,
          prefixIcon: _isSearching
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
              : const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _searchLocations('');
            },
          )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          // Buscar después de una pausa para evitar demasiadas llamadas
          Future.delayed(const Duration(milliseconds: 800), () {
            if (_searchController.text == value) {
              _searchLocations(value);
            }
          });
        },
      ),
    );
  }

  Widget _buildSearchResults() => Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: ListView.builder(
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final result = _searchResults[index];
            return ListTile(
              leading: const Icon(Icons.location_on, color: Colors.blueAccent),
              title: Text(
                result['name'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${result['city'] ?? ''}, ${result['country'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                _moveMapToLocation(result['coordinates']);
                setState(() {
                  _searchResults.clear();
                  _searchController.clear();
                });
              },
            );
          },
        ),
      ),
    );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}