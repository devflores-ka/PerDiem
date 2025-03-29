import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class UbicacionActual extends StatefulWidget {
  const UbicacionActual({super.key});

  @override
  State<UbicacionActual> createState() => _UbicacionActualState();
}

class _UbicacionActualState extends State<UbicacionActual> {
  LatLng? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Call getUbicacionActual immediately when the widget is first created
    getUbicacionActual();
  }

  Future<Position> determinarPosicion() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están desactivados.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Se requieren permisos de ubicación.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Los permisos de ubicación están denegados permanentemente.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void getUbicacionActual() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final position = await determinarPosicion();

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Mover el mapa después de que FlutterMap esté renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPosition != null && mounted) {
        _mapController.move(_currentPosition!, 18);
      }
    });

      if (kDebugMode) {
        print('Latitud: ${position.latitude}');
        print('Longitud: ${position.longitude}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al obtener la ubicación: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Ubicación tiempo real'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: getUbicacionActual,
          ),
        ],
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
                        onPressed: getUbicacionActual,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _currentPosition == null
                  ? const Center(child: Text('No se pudo obtener la ubicación'))
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
                          child: Text(
                            'Coordenadas: ${_currentPosition?.latitude.toStringAsFixed(4)}, ${_currentPosition?.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
}