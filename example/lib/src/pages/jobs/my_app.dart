import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

import '../../managers/location_manager.dart';
import '../../pages/search/search_screen.dart';
import '../../services/offers_service.dart';
import '../../utils/ofertas/detalle_oferta.dart';
import '../../utils/tarjetas.dart';
import '../../widgets/rating_display.dart';
import '../auth/auth.dart';
import '../verificacion/verificacion_screen.dart';
import 'formulario_trabajo.dart';

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
  List<String> _userIds = [];

  String _userRole = 'user';

  // User location variables
  double _userLatitude = 0.0;
  double _userLongitude = 0.0;
  bool _locationError = false;
  String _locationErrorMessage = '';

  late LocationManager _locationManager;

  // Variable para el listener
  StreamSubscription<AuthState>? _authSubscription;

  // VARIABLES PARA VISUALIZAR FILTROS
  String? _activeQuery;
  String? _activeCategory;
  String? _activeOficio;

  @override
  void initState() {
    super.initState();

    _locationManager = LocationManager();

    _setupLocationListener();

    _verificarSesion();

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
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async { // ✅ Asignar la subscription
      final session = data.session;
      
      if (mounted) { // ✅ Verificar que el widget esté montado
        setState(() {
          _user = data.session?.user;
        });
      }

      // 2. Si hay usuario, consultar su ROL en la base de datos pública
      if (session?.user != null) {
        try {
          final doc = await supabase
              .schema('chats')
              .from('users')
              .select('role')
              .eq('id', session!.user.id)
              .maybeSingle();

          if (mounted && doc != null) {
            setState(() {
              _userRole = doc['role'] ?? 'user';
            });
            
            // Debug para que veas qué rol detectó
            if (kDebugMode) print('👤 Rol detectado: $_userRole');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error obteniendo rol: $e');
          }
        }
      } else {
        // Si no hay sesión, asumimos rol de usuario normal (o invitado)
        if (mounted) setState(() => _userRole = 'user');
      }

    });
  }

  // Actualizar dispose para limpiar el listener
  @override
  void dispose() {
    _authSubscription?.cancel();

    // Limpiar listener del LocationManager
    _locationManager.removeListener(_setupLocationListener);

    super.dispose();
  }

  /// Obtiene las ofertas desde Supabase y actualiza el estado visual de los filtros
  Future<void> _cargarTarjetas({
    String? query,
    String? category,
    String? oficioName,
  }) async {
    if (mounted) {
      setState(() {
        _cargando = true;
        // Guardamos los filtros actuales para mostrarlos en el banner
        _activeQuery = query;
        _activeCategory = category;
        _activeOficio = oficioName;
      });
    }

    try {
      final offersService = OffersService();
      final posicionUsuario = LatLng(_userLatitude, _userLongitude);

      final ofertas = await offersService.getNearbyOffers(
        position: posicionUsuario,
        query: query,
        category: category,
        oficioName: oficioName,
        radius: 20.0,
      );

      final tarjetas = <TarjetaServicio>[];
      final coordenadas = <Map<String, double>>[];
      final ids = <String>[];
      final names = <String>[];
      final userIds = <String>[];

      for (var oferta in ofertas) {
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
          numResenas: '2.5k',
          esFavorito: false,
        ),);

        coordenadas.add({
          'latitud': (oferta['latitud'] ?? 0.0).toDouble(),
          'longitud': (oferta['longitud'] ?? 0.0).toDouble(),
        });
        ids.add(oferta['id'].toString());
        names.add(oferta['name']?.toString() ?? '');
        userIds.add(user['id']?.toString() ?? '');
      }

      if (mounted) {
        setState(() {
          _tarjetas = tarjetas;
          _coordenadas = coordenadas;
          _ids = ids;
          _names = names;
          _userIds = userIds;
          _cargando = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error al cargar tarjetas: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Redirige al formulario o autenticación
  void _manejarBotonFlotante() {
    _verificarIdentidadYNavegar();
  }

  // Función auxiliar para verificar si el usuario puede operar
  Future<void> _verificarIdentidadYNavegar() async {
    // 1. Si no está logueado, mandar a Login (Lógica actual)
    if (_user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
      return;
    }

    // Mostrar carga rápida
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Consultar el estado real en la base de datos
      final data = await supabase
          .schema('chats')
          .from('users')
          .select('verification_status')
          .eq('id', _user!.id)
          .single();

      // Cerrar loading
      if (mounted) Navigator.pop(context);

      final status = data['verification_status'] as String? ?? 'none';

      // 3. Evaluar el estado
      if (status == 'verified') {
        // ✅ APROBADO: Dejar pasar al formulario
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormularioTrabajo()),
          ).then((_) => _cargarTarjetas());
        }
      } else {
        // ⛔ BLOQUEADO: Mostrar alerta según el estado
        _mostrarAlertaVerificacion(status);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Cerrar loading si falla
      if (kDebugMode) print('Error verificando usuario: $e');
      // En caso de error de red, podrías decidir dejar pasar o bloquear. 
      // Por seguridad, mejor mostrar error.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verificando cuenta: $e')),
      );
    }
  }

  // Popup bonito para explicar por qué no puede pasar
  void _mostrarAlertaVerificacion(String status) {
    var titulo = 'Verificación Requerida';
    var mensaje = 'Para seguridad de la comunidad, necesitamos validar tu identidad antes de publicar trabajos.';
    var btnTexto = 'Verificar Ahora';
    var icono = Icons.gpp_maybe;
    Color color = Colors.orange;

    if (status == 'pending') {
      titulo = 'Verificación en Proceso';
      mensaje = 'Tus documentos están siendo revisados por nuestro equipo. Te avisaremos pronto.';
      btnTexto = 'Entendido';
      icono = Icons.hourglass_top;
      color = Colors.blue;
    } else if (status == 'rejected') {
      titulo = 'Solicitud Rechazada';
      mensaje = 'Hubo un problema con tus documentos. Por favor, intenta subirlos nuevamente.';
      btnTexto = 'Intentar de nuevo';
      icono = Icons.cancel;
      color = Colors.red;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(icono, color: color), const SizedBox(width: 10), Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18)))]),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (status != 'pending') {
                // ✅ AQUI CONECTAMOS LA PANTALLA
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                ).then((_) {
                  // Cuando vuelva, podríamos recargar el estado por si ya lo envió
                  // _verificarIdentidadYNavegar(); // Opcional
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            child: Text(btnTexto),
          ),
        ],
      ),
    );
  }

  // Método para forzar actualización de ubicación
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text(
        'PerDiem',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          
        ),
      ),
      centerTitle: false, // Cambié esto de true a false
      elevation: 2,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black, size: 28),
          tooltip: 'Buscar servicio',
          onPressed: () async {
            // 1. Navegar a la pantalla de búsqueda y esperar el resultado
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );

            // 2. Si el usuario buscó algo (no volvió con atrás sin hacer nada)
            if (result != null && mounted) {
              final query = result['query'] as String?;
              final categoryMap = result['category'] as Map<String, dynamic>?;
              final oficioMap = result['oficio'] as Map<String, dynamic>?;
              
              if (kDebugMode) {
                print('🔎 Filtrando por: Texto="$query", Cat="${categoryMap?['name']}", Oficio="${oficioMap?['name']}"');
              }

              // 3. Recargar las tarjetas con los filtros
              _cargarTarjetas(
                query: query,
                category: categoryMap?['name'], // Pasamos el nombre de la categoría
                oficioName: oficioMap?['name'], // Pasamos el nombre del oficio
              );
            }
          },
        ),
      ],
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
            : CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Permite refresh aun vacío
          slivers: [
            // Header con subtítulo
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 15, 10, 10),
                child: Text(
                  l10n.availableServices,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // BANNER DE FILTROS (Siempre visible si hay filtros activos)
            _buildActiveFiltersBanner(),

            // Banner de sponsor inicial (SOLO UNO, borré el duplicado)
            SliverToBoxAdapter(
              child: _buildSponsorBanner(),
            ),

            // Lógica de lista o mensaje de vacío
            if (_tarjetas.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay ofertas con estos filtros',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      // Botón extra para limpiar filtros si está vacío
                      if (_activeCategory != null || _activeQuery != null)
                        TextButton.icon(
                          onPressed: () {
                             _cargarTarjetas(); // Recargar sin filtros
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Filtros borrados')),
                             );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Ver todas las ofertas'),
                        ),
                    ],
                  ),
                ),
              )
            else
              // Grid de tarjetas intercalado con banners de sponsor
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    // Cada 4 tarjetas, insertar un banner de sponsor
                    if (index > 0 && index % 4 == 0) {
                      return Column(
                        children: [
                          _buildSponsorBanner(),
                          _buildTarjetaRow(index),
                        ],
                      );
                    }

                    if (index >= _tarjetas.length) return null;

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
    floatingActionButton: _userRole == 'worker' 
      ? FloatingActionButton(
          heroTag: 'btn_flotante_trab',
          onPressed: _manejarBotonFlotante,
          tooltip: 'Publicar servicio',
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add, color: Colors.white),
        )
      : null, // null oculta el botón
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  );
}

// WIDGET Banner de Filtros Activos
  Widget _buildActiveFiltersBanner() {
    // Solo mostrar si hay algún filtro activo
    final hasFilter = (_activeQuery != null && _activeQuery!.isNotEmpty) ||
                      (_activeCategory != null && _activeCategory!.isNotEmpty) ||
                      (_activeOficio != null && _activeOficio!.isNotEmpty);

    if (!hasFilter) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 5, 10, 15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono de filtro
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: const Icon(Icons.filter_alt, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            
            // Texto descriptivo de los filtros
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultados filtrados por:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_activeCategory != null)
                        _buildFilterChip(Icons.category, _activeCategory!, Colors.orange),
                      if (_activeOficio != null)
                        _buildFilterChip(Icons.work, _activeOficio!, Colors.purple),
                      if (_activeQuery != null && _activeQuery!.isNotEmpty)
                        _buildFilterChip(Icons.search, '"$_activeQuery"', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
            
            // Botón de BORRAR FILTROS
            IconButton(
              onPressed: () {
                // ✅ Volver a cargar sin parámetros (limpia todo)
                _cargarTarjetas(); 
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Filtros borrados. Mostrando todo lo cercano.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Borrar filtros',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper pequeño para los chips de colores
  Widget _buildFilterChip(IconData icon, String label, MaterialColor color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.shade800,
            ),
          ),
        ],
      ),
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
              userId: _userIds[index],
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

// Método para construir banner publicitario
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