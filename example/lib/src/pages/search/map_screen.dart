// Archivo: lib/screens/map_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

import '../../managers/location_manager.dart';
import '../../managers/workers_filter_manager.dart';
import '../../services/workers_service.dart';
import '../../utils/worker_marker_widget.dart';
import '../../widgets/location_selector.dart';
import '../user/permisos/permissions_page.dart';
import '../user/personal/user_profile_view_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controladores y servicios
  final MapController _mapController = MapController();
  final WorkersService _workersService = WorkersService();

  // Managers
  late LocationManager _locationManager;
  late WorkersFilterManager _filterManager;

  @override
  void initState() {
    super.initState();
    _locationManager = LocationManager();
    _filterManager = WorkersFilterManager();

    // Escuchar cambios en la ubicación del usuario
    _setupLocationListener();
    _initializeLocation();
  }

  // Configurar listener para cambios de ubicación
  void _setupLocationListener() {
    _locationManager.addListener(() {
      if (_locationManager.currentPosition != null) {
        if (kDebugMode) {
          print('🗺️ Ubicación del usuario cambió, actualizando mapa y trabajadores');
        }

        //  CORRECCIÓN: Solo mover el mapa si está listo
        try {
          _mapController.move(_locationManager.currentPosition!, 15);
                } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error moviendo mapa: $e');
          }
        }

        // Actualizar trabajadores cercanos (esto siempre funciona)
        _refreshNearbyWorkers();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context).languageCode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _filterManager.updateLocalization(l10n);
        
        _filterManager.fetchCategories(currentLocale); 
      }
    });
  }

  //  MEJORADO: Método para cambiar ubicación con mejor UX
  void _showLocationSelectionDialog(BuildContext context) async {
    final locationManager = Provider.of<LocationManager>(context, listen: false);

    if (kDebugMode) {
      print('🗺️ Abriendo selector de ubicación desde: ${locationManager.currentPosition}');
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectorScreen(
          initialPosition: locationManager.currentPosition ??
              const LatLng(-33.4489, -70.6693), // Santiago por defecto
        ),
      ),
    );

    if (result != null && result is LatLng) {
      if (kDebugMode) {
        print('🗺️ Nueva ubicación seleccionada: $result');
      }

      //  MEJORADO: Actualizar ubicación y mostrar loading
      _filterManager.setLoading(true);

      try {
        // Actualizar la posición en el LocationManager
        await locationManager.updatePosition(result, _filterManager.determineSector);

        // Centrar el mapa en la nueva posición con animación
        _mapController.move(result, 15);

        // Refrescar trabajadores cercanos
        await _refreshNearbyWorkers();

        if (kDebugMode) {
          print(' Ubicación actualizada exitosamente');
        }

        // Mostrar mensaje de confirmación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Ubicación actualizada'),
              duration: Duration(seconds: 2),
            ),
          );
        }

      } catch (e) {
        if (kDebugMode) {
          print('❌ Error actualizando ubicación: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error actualizando ubicación: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        _filterManager.setLoading(false);
      }
    }
  }

  // Refresh con mejor manejo de errores y debug completo
  Future<void> _refreshNearbyWorkers() async {
    final currentPosition = _locationManager.currentPosition;
    if (currentPosition == null) {
      if (kDebugMode) {
        print('⚠️ No hay ubicación actual para buscar trabajadores');
      }
      return;
    }

    // OBTENER USUARIO ACTUAL PARA DEBUGGING
    final currentUser = Supabase.instance.client.auth.currentUser;

    _filterManager.setLoading(true);

    //  1. Lógica Correcta: Usamos la primera opción de la lista actual del manager
    // Esto funciona en español ("Categorías"), inglés ("Categories"), etc.
    final defaultCategory = _filterManager.categories.isNotEmpty ? _filterManager.categories.first : 'Categorías';
    final defaultSkill = _filterManager.skills.isNotEmpty ? _filterManager.skills.first : 'Oficios';

    //  2. Preparamos los filtros para enviar al servicio
    // Si la selección es igual al texto por defecto, enviamos NULL (sin filtro)
    final categoryFilterToUse = _filterManager.selectedCategory == defaultCategory
        ? null
        : _filterManager.selectedCategory;

    final skillFilterToUse = _filterManager.selectedSkill == defaultSkill
        ? null
        : _filterManager.selectedSkill;

    if (kDebugMode) {
      print('🔄 === REFRESH NEARBY WORKERS DEBUG ===');
      print('📂 Filtro categoría UI: ${_filterManager.selectedCategory}');
      print('📤 Enviando a DB: $categoryFilterToUse'); // Debe ser null si no elegiste nada
    }

    try {

      //  AGREGAR DEBUG ESPECÍFICO ANTES DE LA LLAMADA
      if (kDebugMode) {
        await _workersService.debugWorkerFiltering(currentPosition);
      }

      // Pasamos las variables correctas
      final workers = await _workersService.getNearbyWorkers(
        currentPosition,
        categoryFilterToUse, 
        skillFilterToUse,
      );

      if (mounted) {
        // ... tu código de debug existente ...

        _filterManager.setNearbyWorkers(workers);

        if (kDebugMode) {
          print('Trabajadores cercanos actualizados en FilterManager: ${workers.length}');
        }
      }
    } catch (e) {
      // ... manejo de errores ...
      if (kDebugMode) print('❌ Error actualizando trabajadores: $e');
    } finally {
      if (mounted) {
        _filterManager.setLoading(false);
      }
    }
  }

  // Construcción de marcadores con debug mejorado
  List<Marker> _buildWorkerMarkers(List<Map<String, dynamic>> workers) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (kDebugMode) {
      print('🗺️ === CONSTRUYENDO MARCADORES ===');
      print('📍 Creando ${workers.length} marcadores de trabajadores');
      print('👤 Usuario actual: ${currentUser?.id}');
    }

    final markers = <Marker>[];

    for (var i = 0; i < workers.length; i++) {
      final worker = workers[i];
      final user = worker['user'];

      if (user == null) {
        if (kDebugMode) {
          print('⚠️ [$i] Trabajador sin datos de usuario: $worker');
        }
        continue;
      }

      try {
        final lat = worker['latitud'] is String
            ? double.parse(worker['latitud'])
            : worker['latitud'].toDouble();
        final lng = worker['longitud'] is String
            ? double.parse(worker['longitud'])
            : worker['longitud'].toDouble();

        final markerPosition = LatLng(lat, lng);
        final isCurrentUser = user['id'] == currentUser?.id;

        if (kDebugMode) {
          print('🗺️ [$i] Creando marcador para ${user['firstName']} ${user['lastName']} en $lat, $lng ${isCurrentUser ? '👤 (TU)' : ''}');
        }

        //  IMPORTANTE: CREAR MARCADORES PARA TODOS LOS USUARIOS
        final marker = Marker(
          point: markerPosition,
          width: 120,
          height: 165,
          child: GestureDetector(
            onTap: () => _showWorkerDetails(worker),
            child: Stack(
              children: [
                WorkerMarkerWidget(
                  avatarUrl: user['imageUrl'] ?? 'https://ui-avatars.com/api/?name=${user['firstName']}&background=0D8ABC&color=fff&size=128&rounded=true',
                  fullName: '${user['firstName']} ${user['lastName']}',
                  rating: user['rating'] != null ? user['rating'].toDouble() : 0.0,
                  ratingCount: user['rating_count'] ?? 0,
                ),
                //  Indicador visual para el usuario actual (opcional)
                if (isCurrentUser)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        markers.add(marker);

      } catch (e) {
        if (kDebugMode) {
          print('❌ Error creando marcador [$i]: $e');
          print('   Datos del trabajador: $worker');
        }
        continue;
      }
    }

    //  VERIFICACIÓN FINAL
    if (kDebugMode) {
      print(' Marcadores creados exitosamente: ${markers.length}');

      // ignore: prefer_expression_function_bodies
      final currentUserMarkers = markers.where((marker) {
        // Esta verificación es aproximada, pero nos da una idea
        return true; // Mostramos todos los marcadores
      }).length;

      print('📊 Total marcadores en mapa: $currentUserMarkers');

      if (markers.isEmpty && workers.isNotEmpty) {
        print('❌ PROBLEMA: Hay trabajadores pero no se crearon marcadores!');
      }
    }

    return markers;
  }

  //  NUEVO: Método para sincronizar con cambios desde el perfil
  Future<void> _initializeLocation() async {
    final success = await _locationManager.initializeLocation(
        _filterManager.determineSector, forceUpdate: true,
    );

    if (!success) {
      await _redirectToPermissionsScreen();
    } else {
      // Cargar trabajadores cercanos
      await _refreshNearbyWorkers();
    }
  }

  void _centerMapOnUser() {
    final currentPosition = _locationManager.currentPosition;
    if (currentPosition != null) {
      _mapController.move(currentPosition, 18);
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
      await _initializeLocation();
    } else {
      _locationManager.setErrorMessage('Permiso de ubicación no concedido');
      _locationManager.setLoading(false);
    }
  }

  // Muestra la hoja inferior con los oficios
  void _showSkillFilterSheet(BuildContext context) {
    final filterManager = Provider.of<WorkersFilterManager>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.selectOneTrade,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filterManager.skills.length,
                itemBuilder: (context, index) {
                  final skill = filterManager.skills[index];
                  return ListTile(
                    leading: Icon(
                      filterManager.getSkillIcon(skill),
                      color: filterManager.selectedSkill == skill
                          ? Colors.blueAccent
                          : Colors.grey,
                    ),
                    title: Text(skill),
                    trailing: filterManager.selectedSkill == skill
                        ? const Icon(Icons.check, color: Colors.blueAccent)
                        : null,
                    onTap: () {
                      filterManager.setSkill(skill);
                      _refreshNearbyWorkers();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationManager.removeListener(_setupLocationListener);
    super.dispose();
  }

  // Versión simplificada (ALTERNATIVA)
  Widget _buildFilterStrip(BuildContext context, WorkersFilterManager filterManager) => Container(
      margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón de selección de ubicación
          _buildLocationButton(context),

          const SizedBox(width: 8),

          // Divisor vertical
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
          ),

          const SizedBox(width: 8),

          // Botón para mostrar filtros de categorías
          Expanded(
            child: _buildCategoryFilterButton(context, filterManager),
          ),

          const SizedBox(width: 8),

          // Divisor vertical
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
          ),

          const SizedBox(width: 8),

          // Botón para mostrar filtros de habilidades
          Expanded(
            child: _buildSkillFilterButton(context, filterManager),
          ),
        ],
      ),
    );

// Versión simplificada de los botones
  Widget _buildCategoryFilterButton(BuildContext context, WorkersFilterManager filterManager) => GestureDetector(
      onTap: () {
        _showCategoryFilterSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filterManager.getCategoryIcon(filterManager.selectedCategory),
              color: Colors.blueAccent,
              size: 18,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                filterManager.selectedCategory,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );

  Widget _buildSkillFilterButton(BuildContext context, WorkersFilterManager filterManager) {
    // 1. Verificar si hay una categoría específica seleccionada
    // Asumimos que 'Todos' es el valor por defecto cuando no se ha seleccionado una específica
    final bool isCategorySelected = filterManager.selectedCategory != filterManager.categories.first;
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      // 2. Si no hay categoría seleccionada, el onTap es null (bloqueado)
      // Si hay categoría, mostramos la hoja de filtros
      onTap: isCategorySelected 
          ? () {
              _showSkillFilterSheet(context);
            } 
          : () {
              // Opcional: Mostrar un mensaje pequeño indicando que deben seleccionar categoría
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.firstSelectOneCategorie),
                  duration: Duration(seconds: 1),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filterManager.getSkillIcon(filterManager.selectedSkill),
              // 3. Cambiar color visualmente (Gris si está bloqueado, Azul si está activo)
              color: isCategorySelected ? Colors.blueAccent : Colors.grey.shade400,
              size: 18,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                filterManager.selectedSkill,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  // Texto gris si está bloqueado
                  color: isCategorySelected ? Colors.black : Colors.grey.shade400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down, 
              // Flecha gris claro si está bloqueado
              color: isCategorySelected ? Colors.grey : Colors.grey.shade300, 
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

// Botón para cambiar ubicación manualmente
  Widget _buildLocationButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        // Aquí implementaremos la funcionalidad para cambiar ubicación
        _showLocationSelectionDialog(context);
      },
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blueAccent),
          SizedBox(width: 5),
          Text(
            l10n.locationSingle,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

// Muestra la hoja inferior con las categorías
  void _showCategoryFilterSheet(BuildContext context) {
    final filterManager = Provider.of<WorkersFilterManager>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.selectOneCategorie,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filterManager.categories.length,
                itemBuilder: (context, index) {
                  final category = filterManager.categories[index];
                  return ListTile(
                    leading: Icon(
                      filterManager.getCategoryIcon(category),
                      color: filterManager.selectedCategory == category
                          ? Colors.blueAccent
                          : Colors.grey,
                    ),
                    title: Text(category),
                    trailing: filterManager.selectedCategory == category
                        ? const Icon(Icons.check, color: Colors.blueAccent)
                        : null,
                    onTap: () {
                      filterManager.setCategory(category);
                      _refreshNearbyWorkers();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkerDetails(Map<String, dynamic> worker) {
    final user = worker['user'];

    debugPrint('🔍 Mostrando detalles del trabajador:');
    debugPrint('   - ID: ${user['id']}');
    debugPrint('   - Nombre: ${user['firstName']} ${user['lastName']}');
    debugPrint('   - Imagen: ${user['imageUrl']}');
    debugPrint('   - Worker completo: $worker');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileViewScreen(
          userId: user['id'],
          userName: '${user['firstName']} ${user['lastName']}',
          userImageUrl: user['imageUrl'],
          userDescription: user['descripcion'],
          userLatitude: worker['latitud'],
          userLongitude: worker['longitud'],
        ),
      ),
    );
  }

  @override
  // ignore: prefer_expression_function_bodies
  Widget build(BuildContext context) {
    // Envolver en providers para proporcionar managers a los widgets hijos
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _locationManager),
        ChangeNotifierProvider.value(value: _filterManager),
      ],
      child: Scaffold(
        extendBodyBehindAppBar: true, // <--- ESTO HACE QUE EL MAPA PASE POR DEBAJO
        body: _buildBody(),
      ),
    );
  }

  // ignore: prefer_expression_function_bodies
  Widget _buildBody() {
    // Consumir el estado de los managers
    return Consumer2<LocationManager, WorkersFilterManager>(
      builder: (context, locationManager, filterManager, child) {
        // Mostrar cargando si cualquiera de los managers está cargando
        if (locationManager.isLoading || filterManager.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Mostrar mensaje de error si hay algún error
        if (locationManager.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  locationManager.errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeLocation,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        // Verificar que tenemos posición
        if (locationManager.currentPosition == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Mostrar el mapa con la franja de filtros superior
        return Stack(
          children: [
            // Mapa a pantalla completa
            _buildMap(locationManager, filterManager),

            // Franja de filtros en la parte superior
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _buildFilterStrip(context, filterManager),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap(LocationManager locationManager, WorkersFilterManager filterManager) { 
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: locationManager.currentPosition!,
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
            Padding(
              padding: const EdgeInsets.all(50.0),
              child: MarkerLayer(
                markers: [
                  if (filterManager.nearbyWorkers != null)
                    ..._buildWorkerMarkers(filterManager.nearbyWorkers!),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. NUEVO: Botón de Recargar
              FloatingActionButton(
                heroTag: 'btn_refresh', // Necesario si hay 2 FABs en pantalla
                onPressed: _refreshNearbyWorkers,
                backgroundColor: Colors.white,
                mini: true,
                child: const Icon(Icons.refresh, color: Colors.black87),
              ),
              const SizedBox(height: 12), // Espacio entre botones
              
              // 2. Botón de Centrar (Existente)
              FloatingActionButton(
                heroTag: 'btn_center', // Necesario si hay 2 FABs en pantalla
                onPressed: _centerMapOnUser,
                backgroundColor: Colors.white,
                mini: true,
                child: const Icon(Icons.my_location, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
        // Indicador de depuración
        if (kDebugMode)
          Positioned(
            left: 16,
            top: 80, // Movido más abajo para no interferir con la franja de filtros
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white.withOpacity(0.8),
              child: Text(
                'Workers: ${filterManager.nearbyWorkers?.length ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        // Indicador de posición actual
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
              child: Text(
                l10n.yourUbi,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}