import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'permissions_page.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  String? _currentSector;
  bool _isLoading = true;
  String _errorMessage = '';
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndGetLocation();
  }

  String _determineSector(LatLng position) {
    // Dividir el área en 4 cuadrantes
    double centerLat = position.latitude;
    double centerLon = position.longitude;

    if (position.latitude >= centerLat && position.longitude >= centerLon) {
      return 'Noreste';
    } else if (position.latitude >= centerLat && position.longitude < centerLon) {
      return 'Noroeste';
    } else if (position.latitude < centerLat && position.longitude >= centerLon) {
      return 'Sureste';
    } else {
      return 'Suroeste';
    }
  }

  Future<void> _checkLocationPermissionAndGetLocation() async {
    try {
      // Verify location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _redirectToPermissionsScreen();
        return;
      }

      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _redirectToPermissionsScreen();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permanent denial - redirect to app settings
        await _redirectToPermissionsScreen();
        return;
      }

      // Configure location settings
      LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      // Try to get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings
      );

      // Update state with current position
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentSector = _determineSector(_currentPosition!);
        _isLoading = false;
      });

      // Start position stream
      Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position newPosition) {
          _updateLocation(newPosition);
        },
        onError: (error) {
          setState(() {
            _errorMessage = 'Error en el seguimiento de ubicación: ${error.toString()}';
          });
        },
        cancelOnError: true,
      );

    } catch (e) {
      setState(() {
        _errorMessage = 'Error al obtener la ubicación: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _updateLocation(Position position) {
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentSector = _determineSector(_currentPosition!);
        
        // Mover el mapa a la nueva ubicación
        _mapController.move(_currentPosition!, 18);
      });
    }
  }

  Future<void> _redirectToPermissionsScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PermisosUbicacionScreen(),
      ),
    );

    if (result == true) {
      await _checkLocationPermissionAndGetLocation();
    } else {
      setState(() {
        _errorMessage = 'Permiso de ubicación no concedido';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Mapa'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage, 
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _checkLocationPermissionAndGetLocation,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Expanded(
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentPosition!, 
                              minZoom: 5, 
                              maxZoom: 25, 
                              initialZoom: 18,
                              keepAlive: true,
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
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 50,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                'Sector Actual: ${_currentSector ?? "No determinado"}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Coordenadas: ${_currentPosition?.latitude.toStringAsFixed(4)}, ${_currentPosition?.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
}