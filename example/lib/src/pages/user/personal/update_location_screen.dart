// Archivo: lib/screens/profile/update_location_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/location_selector.dart';

class UpdateLocationScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const UpdateLocationScreen({
    super.key,
    this.initialPosition,
  });

  @override
  State<UpdateLocationScreen> createState() => _UpdateLocationScreenState();
}

class _UpdateLocationScreenState extends State<UpdateLocationScreen> {
  final MapController _mapController = MapController();
  final supabase = Supabase.instance.client;

  LatLng? _currentPosition;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    try {
      // Si hay una posición inicial, la usamos
      if (widget.initialPosition != null) {
        _currentPosition = widget.initialPosition;
      } else {
        // Si no, cargamos la ubicación guardada del usuario
        await _loadUserLocation();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error inicializando ubicación: $e');
      }
      // Posición por defecto (Santiago, Chile)
      _currentPosition = const LatLng(-33.4489, -70.6693);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final locationData = await supabase
          .schema('jobs')
          .from('worker_locations')
          .select('latitud, longitud')
          .eq('user_id', user.id)
          .eq('user_type', 'worker')
          .maybeSingle();

      if (locationData != null) {
        final lat = locationData['latitud'] is String
            ? double.parse(locationData['latitud'])
            : locationData['latitud'].toDouble();
        final lng = locationData['longitud'] is String
            ? double.parse(locationData['longitud'])
            : locationData['longitud'].toDouble();

        _currentPosition = LatLng(lat, lng);
      } else {
        // Si no hay ubicación guardada, usar posición por defecto
        _currentPosition = const LatLng(-33.4489, -70.6693);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando ubicación del usuario: $e');
      }
      rethrow;
    }
  }

  void _showLocationSelector() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectorScreen(
          initialPosition: _currentPosition ?? const LatLng(-33.4489, -70.6693),
        ),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() {
        _currentPosition = result;
      });

      // Centrar el mapa en la nueva posición
      _mapController.move(result, 15);
    }
  }

  Future<void> _saveLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ubicación seleccionada'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar si ya existe un registro para este usuario
      final existingLocation = await supabase
          .schema('jobs')
          .from('worker_locations')
          .select('user_id')
          .eq('user_id', user.id)
          .eq('user_type', 'worker')
          .maybeSingle();

      final locationData = {
        'user_id': user.id,
        'latitud': _currentPosition!.latitude,
        'longitud': _currentPosition!.longitude,
        'user_type': 'worker',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingLocation != null) {
        // Actualizar registro existente
        await supabase
            .schema('jobs')
            .from('worker_locations')
            .update(locationData)
            .eq('user_id', user.id)
            .eq('user_type', 'worker');
      } else {
        // Crear nuevo registro
        locationData['created_at'] = DateTime.now().toIso8601String();
        await supabase
            .schema('jobs')
            .from('worker_locations')
            .insert(locationData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación guardada correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Regresar al perfil con la nueva ubicación
        Navigator.pop(context, _currentPosition);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando ubicación: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar ubicación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Mi Ubicación'),
        backgroundColor: Colors.blue,
        elevation: 2,
        shadowColor: Colors.blue.withOpacity(0.3),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Botón para cambiar ubicación usando el selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showLocationSelector,
                icon: const Icon(Icons.search),
                label: const Text('Buscar Ubicación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Mapa
          Expanded(
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 15,
                minZoom: 5,
                maxZoom: 25,
                onTap: (tapPosition, point) {
                  // Permitir seleccionar ubicación tocando el mapa
                  setState(() {
                    _currentPosition = point;
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
                      point: _currentPosition!,
                      width: 80,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botones de acción
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
}