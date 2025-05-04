import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/location_service.dart';
import '../../widgets/worker_marker_widget.dart';
import '../user/permissions_page.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controladores y servicios
  final MapController _mapController = MapController();
  final WorkersService _workersService = WorkersService();

  // Estado del mapa
  LatLng? _currentPosition;
  String? _currentSector;
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>>? _nearbyWorkers;

  // Lista de categorías disponibles
  final List<String> _categories = [
    'Todos',
    'Plomería',
    'Electricidad',
    'Carpintería',
    'Albañilería',
    'Jardinería',
    'Limpieza',
    'Pintura',
    'pruebas',
  ];

  // Categoría seleccionada actualmente (inicia con "Todos")
  String _selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndGetLocation();
  }

  List<Marker> _buildWorkerMarkers(List<Map<String, dynamic>> workers) {
    if (kDebugMode) {
      print('Building ${workers.length} worker markers');
    }

    return workers.map((worker) {
      final user = worker['user'];

      if (user == null) {
        if (kDebugMode) {
          print('Worker without user data: $worker');
        }
        return Marker(
          point: LatLng(0, 0),
          child: Container(),
        );
      }

      try {
        final lat = worker['latitud'] is String
            ? double.parse(worker['latitud'])
            : worker['latitud'].toDouble();
        final lng = worker['longitud'] is String
            ? double.parse(worker['longitud'])
            : worker['longitud'].toDouble();

        final markerPosition = LatLng(lat, lng);

        if (kDebugMode) {
          print('Creating marker for ${user['firstName']} at $lat, $lng');
        }

        // Establecemos un tamaño fijo y usando un widget externo para asegurar que
        // el tamaño del marcador sea constante y adecuado
        return Marker(
          point: markerPosition,
          width: 120, // Asignamos un ancho fijo al marcador
          height: 165, // Asignamos una altura fija al marcador
          child: GestureDetector(
            onTap: () => _showWorkerDetails(worker),
            child: WorkerMarkerWidget(
              avatarUrl: user['imageUrl'] ?? 'https://example.com/default-avatar.png',
              fullName: '${user['firstName']} ${user['lastName']}',
              rating: user['rating'] != null ? user['rating'].toDouble() : 0.0,
              ratingCount: user['rating_count'] ?? 0,
            ),
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error creating marker: $e');
          print('Worker data: $worker');
        }
        return Marker(
          point: LatLng(0, 0),
          child: Container(),
        );
      }
    }).where((marker) =>
    marker.point.latitude != 0 && marker.point.longitude != 0,
    ).toList();
  }

  void _showWorkerDetails(Map<String, dynamic> worker) {
    // Changed from 'users' to 'user' to match the actual data structure
    final user = worker['user'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(user['imageUrl'] ?? 'https://example.com/default-avatar.png'),
            ),
            const SizedBox(height: 8),
            Text(
              '${user['firstName']} ${user['lastName']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Categoría: ${worker['category'] ?? 'No especificada'}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${(user['rating'] ?? 0).toDouble()} (${((user['rating_count'] ?? 0) / 1000).toStringAsFixed(1)}K)',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Aquí iría la lógica para contactar al trabajador
                Navigator.pop(context);
              },
              child: const Text('Contactar'),
            ),
          ],
        ),
      ),
    );
  }

  String _determineSector(LatLng position) {
    // Dividir el área en 4 cuadrantes
    final centerLat = position.latitude;
    final centerLon = position.longitude;

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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('Location services are disabled');
        }
        await _redirectToPermissionsScreen();
        return;
      }

      // Check and request location permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('Location permission denied');
          }
          await _redirectToPermissionsScreen();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permanent denial - redirect to app settings
        if (kDebugMode) {
          print('Location permission permanently denied');
        }
        await _redirectToPermissionsScreen();
        return;
      }

      // Configure location settings
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      // Try to get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (kDebugMode) {
        print('Got current position: ${position.latitude}, ${position.longitude}');
      }

      // Update state with current position
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentSector = _determineSector(_currentPosition!);
        _isLoading = false;
      });

      // Fetch nearby workers initially
      await _refreshNearbyWorkers();

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
            if (kDebugMode) {
              print('Location tracking error: $error');
            }
          });
        },
        cancelOnError: true,
      );

    } catch (e) {
      setState(() {
        _errorMessage = 'Error al obtener la ubicación: ${e.toString()}';
        _isLoading = false;
        if (kDebugMode) {
          print('Location error: $e');
        }
      });
    }
  }

  Future<void> _refreshNearbyWorkers() async {
    if (_currentPosition != null) {
      if (kDebugMode) {
        print('Refreshing nearby workers');
      }

      final categoryFilter = _selectedCategory == 'Todos' ? null : _selectedCategory;
      final workers = await _workersService.getNearbyWorkers(
          _currentPosition!,
          categoryFilter,
      );

      if (mounted) {
        setState(() {
          _nearbyWorkers = workers;
          if (kDebugMode) {
            print('Updated nearby workers: ${workers.length}');
          }
        });
      }
    }
  }

  void _updateLocation(Position position) {
    if (mounted) {
      final newPosition = LatLng(position.latitude, position.longitude);
      final distance = const Distance();
      final distanceMoved = _currentPosition != null
          ? distance.as(LengthUnit.Meter, _currentPosition!, newPosition)
          : double.infinity;

      setState(() {
        _currentPosition = newPosition;
        _currentSector = _determineSector(_currentPosition!);
      });

      // Si nos movimos más de 50 metros, actualizar los trabajadores cercanos
      if (distanceMoved > 50) {
        _refreshNearbyWorkers();
      }
    }
  }

  void _centerMapOnUser() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 18);
    }
  }

  void _setCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _refreshNearbyWorkers();
    Navigator.pop(context); // Cerrar el drawer
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
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshNearbyWorkers,
          tooltip: 'Actualizar trabajadores cercanos',
        ),
      ],
    ),
    drawer: _buildCategoryDrawer(),
    body: _buildBody(),
  );

  Widget _buildCategoryDrawer() => Drawer(
    child: Column(
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.filter_list,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  'Filtrar por Categoría',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Categoría actual: $_selectedCategory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: _categories.map((category) => ListTile(
              title: Text(category),
              leading: Icon(
                _getCategoryIcon(category),
                color: _selectedCategory == category ? Colors.blueAccent : Colors.grey,
              ),
              selected: _selectedCategory == category,
              selectedTileColor: Colors.blue.withOpacity(0.1),
              onTap: () => _setCategory(category),
            ),
            ).toList(),
          ),
        ),
      ],
    ),
  );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
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
      );
    }

    if (_currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: _buildMap(),
        ),
        _buildInfoPanel(),
      ],
    );
  }

  Widget _buildMap() => Stack(
    children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentPosition!,
          minZoom: 5,
          maxZoom: 25,
          initialZoom: 18,
          keepAlive: true,
          // Remove the padding parameter as it's not defined in MapOptions
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
          // If you need padding, you can wrap your MarkerLayer in a Padding widget
          Padding(
            padding: const EdgeInsets.all(50.0),
            child: MarkerLayer(
              markers: [
                if (_nearbyWorkers != null)
                  ..._buildWorkerMarkers(_nearbyWorkers!),
              ],
            ),
          ),
        ],
      ),
      Positioned(
        right: 16,
        bottom: 100,
        child: FloatingActionButton(
          onPressed: _centerMapOnUser,
          backgroundColor: Colors.white,
          mini: true,
          child: const Icon(Icons.my_location, color: Colors.black),
        ),
      ),
      // Añadir indicador de depuración
      if (kDebugMode)
        Positioned(
          left: 16,
          top: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white.withOpacity(0.8),
            child: Text(
              'Workers: ${_nearbyWorkers?.length ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      // Añadimos un indicador de posición actual más sutil
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 30),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Tu ubicación',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildInfoPanel() => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(8.0),
    child: Column(
      children: [
        Text(
          'Categoría: $_selectedCategory',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
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
        Text(
          'Trabajadores cercanos: ${_nearbyWorkers?.length ?? 0}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Todos':
        return Icons.work;
      case 'Plomería':
        return Icons.plumbing;
      case 'Electricidad':
        return Icons.electric_bolt;
      case 'Carpintería':
        return Icons.handyman;
      case 'Albañilería':
        return Icons.construction;
      case 'Jardinería':
        return Icons.grass;
      case 'Limpieza':
        return Icons.cleaning_services;
      case 'Pintura':
        return Icons.format_paint;
      default:
        return Icons.category;
    }
  }
}