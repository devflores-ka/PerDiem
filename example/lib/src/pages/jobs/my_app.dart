import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Add this import
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../managers/location_manager.dart';
import '../../services/offers_service.dart';
import '../../utils/ofertas/detalle_oferta.dart';
import '../../utils/tarjetas.dart';
import '../../widgets/rating_display.dart';
import '../auth/auth.dart';
import 'formulario_trabajo.dart'; // Pantalla para publicar servicio

// Formato de moneda
final numberFormat = NumberFormat.currency(
  locale: 'es_CL',
  symbol: '\$',
  decimalDigits: 0,
);

class TrabajoPage extends StatefulWidget {
  const TrabajoPage({super.key});

  @override
  State<TrabajoPage> createState() => _TrabajoPageState();
}

class _TrabajoPageState extends State<TrabajoPage> {
  final supabase = Supabase.instance.client;
  User? _user;
  List<TarjetaServicio> _tarjetas = [];
  List<Map<String, double>> _coordenadas = [];
  bool _cargando = true;
  List<String> _ids = [];
  List<String> _names = [];

  // User location variables
  double _userLatitude = 0.0;
  double _userLongitude = 0.0;
  bool _locationError = false;
  String _locationErrorMessage = '';

  late LocationManager _locationManager;

  // ✅ Agregar variable para el listener
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // ✅ AGREGAR: Inicializar LocationManager
    _locationManager = LocationManager();

    // ✅ AGREGAR: Configurar listener para cambios de ubicación
    _setupLocationListener();

    _verificarSesion();

    // ✅ MODIFICAR: Usar ubicación del LocationManager en lugar de getCurrentLocation
    _initializeFromLocationManager();
  }

  // ✅ NUEVO: Configurar listener para cambios de ubicación
  void _setupLocationListener() {
    _locationManager.addListener(() {
      if (_locationManager.currentPosition != null) {
        if (kDebugMode) {
          print('🏠 Ubicación del usuario cambió en TrabajoPage, actualizando ofertas');
        }

        // Actualizar las coordenadas del usuario
        _userLatitude = _locationManager.currentPosition!.latitude;
        _userLongitude = _locationManager.currentPosition!.longitude;

        // Recargar las ofertas con la nueva ubicación
        _cargarTarjetas();
      }
    });
  }

  // ✅ NUEVO: Inicializar desde LocationManager en lugar de getCurrentLocation
  Future<void> _initializeFromLocationManager() async {
    try {
      // Intentar usar la ubicación ya guardada en LocationManager
      if (_locationManager.currentPosition != null) {
        if (kDebugMode) {
          print('🏠 Usando ubicación guardada del LocationManager');
        }

        setState(() {
          _userLatitude = _locationManager.currentPosition!.latitude;
          _userLongitude = _locationManager.currentPosition!.longitude;
          _locationError = false;
          _locationErrorMessage = '';
        });

        // Cargar ofertas con la ubicación guardada
        await _cargarTarjetas();
        return;
      }

      // Si no hay ubicación guardada, inicializar LocationManager
      if (kDebugMode) {
        print('🏠 No hay ubicación guardada, inicializando LocationManager');
      }

      final success = await _locationManager.initializeLocation(
            (position) => 'Sector determinado', forceUpdate: true, // Puedes personalizar esto
      );

      if (success && _locationManager.currentPosition != null) {
        setState(() {
          _userLatitude = _locationManager.currentPosition!.latitude;
          _userLongitude = _locationManager.currentPosition!.longitude;
          _locationError = false;
          _locationErrorMessage = '';
        });

        await _cargarTarjetas();
      } else {
        // Fallback a getCurrentLocation si LocationManager falla
        await _getCurrentLocation();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error inicializando desde LocationManager: $e');
      }

      // Fallback a getCurrentLocation
      await _getCurrentLocation();
    }
  }

  /// Get the user's current location
  Future<void> _getCurrentLocation() async {
    try {
      // Check location permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) { // ✅ Agregar verificación
              setState(() {
                _locationError = true;
                _locationErrorMessage = 'Permisos de locación denegados';
              });
            }
            return;
          }
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) { // ✅ Agregar verificación
          setState(() {
            _locationError = true;
            _locationErrorMessage = 'Permisos de locación denegados permanentemente';
          });
        }
        return;
      }

      // Get the current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) { // ✅ Agregar verificación
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
        });
      }

      // Ahora tenemos la ubicación, cargar las ofertas
      await _cargarTarjetas();
    } catch (e) {
      if (mounted) { // ✅ Agregar verificación
        setState(() {
          _locationError = true;
          _locationErrorMessage = 'Error obteniendo ubicación: $e';
          _cargando = false;
        });
      }
      if (kDebugMode) {
        print('Error obteniendo ubicación: $e');
      }
    }
  }

  /// Verifica si hay un usuario autenticado
  void _verificarSesion() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) { // ✅ Asignar la subscription
      if (mounted) { // ✅ Verificar que el widget esté montado
        setState(() {
          _user = data.session?.user;
        });
      }
    });
  }

  // ✅ MODIFICAR: Actualizar dispose para limpiar el listener
  @override
  void dispose() {
    _authSubscription?.cancel();

    // ✅ AGREGAR: Limpiar listener del LocationManager
    _locationManager.removeListener(_setupLocationListener);

    super.dispose();
  }

  /// Obtiene las ofertas desde Supabase
  Future<void> _cargarTarjetas() async {
    if (mounted) { // ✅ Agregar verificación
      setState(() => _cargando = true);
    }

    try {
      final offersService = OffersService();
      final posicionUsuario = LatLng(
        _userLatitude, _userLongitude,); // Use the stored user location

      final ofertas = await offersService.getNearbyOffers(
        position: posicionUsuario,
        //category: categoriaSeleccionada, // Opcional
      );

      final tarjetas = <TarjetaServicio>[];
      final coordenadas = <Map<String, double>>[];
      final ids = <String>[];
      final names = <String>[];

      for (var oferta in ofertas) {
        // La información de usuario ya viene incluida en el resultado
        final user = oferta['user'] ?? {};

        tarjetas.add(TarjetaServicio(
          imagenUrl: oferta['image_url'] ?? 'https://placehold.co/150',
          descripcion: oferta['description'] ?? '',
          presupuesto: (oferta['amount'] is double)
              ? oferta['amount']
              : (oferta['amount'] ?? 0).toDouble(),
          nombreUsuario: '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
          avatarUrl: user['imageUrl'] ?? 'https://placehold.co/40',
          calificacion: 4.9,
          // O calcúlalo si tienes este dato
          numResenas: '2.5k',
          // O calcúlalo si tienes este dato
          esFavorito: false,
        ),
        );

        coordenadas.add({
          'latitud': oferta['latitud'] ?? 0.0,
          'longitud': oferta['longitud'] ?? 0.0,
        });
        ids.add(oferta['id'].toString());
        names.add(oferta['name']?.toString() ?? '');
      }

      if (mounted) {
        setState(() {
          _tarjetas = tarjetas;
          _coordenadas = coordenadas;
          _ids = ids;
          _names = names;
          _cargando = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar tarjetas: $e');
      }
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  /// Redirige al formulario o autenticación
  void _manejarBotonFlotante() {
    if (_user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormularioTrabajo()),
      ).then((_) => _cargarTarjetas());
    }
  }

  // ✅ OPCIONAL: Método para forzar actualización de ubicación
  Future<void> _refreshLocation() async {
    setState(() => _cargando = true);

    try {
      // Forzar actualización de ubicación en LocationManager
      final success = await _locationManager.initializeLocation(
            (position) => 'Sector determinado',
        forceUpdate: true, // Si el LocationManager acepta este parámetro
      );

      if (success && _locationManager.currentPosition != null) {
        setState(() {
          _userLatitude = _locationManager.currentPosition!.latitude;
          _userLongitude = _locationManager.currentPosition!.longitude;
          _locationError = false;
          _locationErrorMessage = '';
        });

        await _cargarTarjetas();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refrescando ubicación: $e');
      }

      setState(() {
        _locationError = true;
        _locationErrorMessage = 'Error actualizando ubicación: $e';
        _cargando = false;
      });
    }
  }

  // my_app.dart - Sección del build method rediseñada
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text(
        'PerDiem',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      centerTitle: false, // Cambié esto de true a false
      backgroundColor: Colors.blue,
      elevation: 2,
      shadowColor: Colors.blue.withOpacity(0.3),
    ),
    body: RefreshIndicator(
      onRefresh: _refreshLocation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _locationError
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_locationErrorMessage),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _getCurrentLocation,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        )
            : _tarjetas.isEmpty
            ? const Center(child: Text('No hay ofertas disponibles'))
            : CustomScrollView(
          slivers: [
            // Header con subtítulo
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 15, 10, 10),
                child: Text(
                  'Servicios Disponibles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // Banner de sponsor inicial
            SliverToBoxAdapter(
              child: _buildSponsorBanner(),
            ),

            // Grid de tarjetas intercalado con banners de sponsor
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  // Cada 2 filas (4 tarjetas), insertar un banner de sponsor
                  if (index > 0 && index % 4 == 0) {
                    return Column(
                      children: [
                        _buildSponsorBanner(),
                        _buildTarjetaRow(index),
                      ],
                    );
                  }

                  if (index >= _tarjetas.length) {
                    return null;
                  }

                  // Cada 2 tarjetas, crear una fila
                  if (index % 2 == 0) {
                    return _buildTarjetaRow(index);
                  }

                  return const SizedBox.shrink();
                },
                childCount: _tarjetas.length,
              ),
            ),

            // Espacio final para el FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _manejarBotonFlotante,
      tooltip: 'Publicar servicio',
      backgroundColor: Colors.blue,
      child: const Icon(Icons.add, color: Colors.white),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  );

// Método para construir una fila con 2 tarjetas
  Widget _buildTarjetaRow(int startIndex) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Primera tarjeta
          Expanded(
            child: _buildCompactTarjeta(startIndex),
          ),
          const SizedBox(width: 8),
          // Segunda tarjeta (si existe)
          Expanded(
            child: startIndex + 1 < _tarjetas.length
                ? _buildCompactTarjeta(startIndex + 1)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

// Método para construir tarjeta compacta
  Widget _buildCompactTarjeta(int index) {
    final tarjeta = _tarjetas[index];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetalleOferta(
              imagenUrl: tarjeta.imagenUrl,
              descripcion: tarjeta.descripcion,
              presupuesto: tarjeta.presupuesto,
              nombreUsuario: tarjeta.nombreUsuario,
              avatarUrl: tarjeta.avatarUrl,
              calificacion: tarjeta.calificacion,
              numResenas: tarjeta.numResenas,
              latitud: _coordenadas[index]['latitud']!,
              longitud: _coordenadas[index]['longitud']!,
              offerId: _ids[index],
              offerName: _names[index],
              mostrarCalificacion: true,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen estandarizada
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 120, // Altura fija
                width: double.infinity,
                child: Image.network(
                  tarjeta.imagenUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
            ),

            // Contenido de la tarjeta
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Usuario
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(tarjeta.avatarUrl),
                        radius: 12,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tarjeta.nombreUsuario,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Descripción
                  Text(
                    tarjeta.descripcion,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Precio y calificación
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Calificación con RatingDisplay
                      if (tarjeta.calificacion > 0)
                        RatingDisplay(
                          rating: tarjeta.calificacion,
                          reviewCount: int.tryParse(tarjeta.numResenas) ?? 0,
                          iconSize: 12,
                          showEmpty: false,
                        ),

                      // Precio en formato chileno
                      Text(
                        '${numberFormat.format(tarjeta.presupuesto)} CLP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Método para construir banner de sponsor
  Widget _buildSponsorBanner() => Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200], // Gris ligeramente más oscuro que el fondo
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'SPONSOR',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );

// Método para construir banner publicitario (mantienes el original si lo necesitas)
  Widget _buildAdBanner() => Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Row(
        children: [
          // Icono o imagen del anuncio
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.campaign,
              color: Colors.blue,
              size: 30,
            ),
          ),

          // Contenido del anuncio
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¡Promociona tu servicio!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Llega a más clientes con nuestros planes premium',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Botón CTA
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ElevatedButton(
              onPressed: () {
                // Acción del anuncio
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Redirigiendo a planes premium...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(60, 30),
              ),
              child: const Text(
                'Ver más',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
}