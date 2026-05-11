// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

import '../../services/review_service.dart';
import '../../services/user_service.dart';
import '../../widgets/worker_status_switch.dart';
import '../auth/auth.dart';
import '../jobs/trabajos_screen.dart';
import '../personal/worker_agenda_screen.dart';
import '../personal/worker_schedule_screen.dart';
import 'configuracion/settings_screen.dart';
import 'personal/reviews_screen.dart';
import 'personal/update_categories_screen.dart';
import 'personal/update_location_screen.dart';

class PerfilScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const PerfilScreen({
    super.key,
    this.onProfileUpdated,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  String _currentLocationAddress = 'Cargando ubicación...';
  bool _isLoadingLocation = true;
  final supabase = Supabase.instance.client;
  bool _isWorker = false;

  // Estado de carga y autenticación
  bool isLoading = true;
  bool isUserLoggedIn = false;

  // Datos del usuario
  String? firstName = '';
  String? lastName = '';
  String? imageUrl = 'https://placehold.co/100';
  String? descripcion = '';

  // Calificaciones
  double averageRating = 0.0;
  int totalReviews = 0;
  bool isLoadingReviews = true;
  UserRating? userRating;

  // Trabajos
  List<Map<String, dynamic>> _trabajosRecientes = [];
  bool _isLoadingTrabajos = true;

  // Habilidades
  List<Map<String, dynamic>> userSkills = [];
  List<Map<String, dynamic>> allSkills = [];
  final List<String> nivelesHabilidad = ['Principiante', 'Intermedio', 'Avanzado', 'Experto'];

  // Categorías y oficios
  List<Map<String, dynamic>> _userCategories = [];
  Map<int, List<Map<String, dynamic>>> _userOficios = {};

  // Controllers
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _searchSkillController = TextEditingController();
  bool _isEditingDescription = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (kDebugMode) {
      print('🔵 PerfilScreen - initState ejecutado');
    }
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descripcionController.dispose();
    _searchSkillController.dispose();
    super.dispose();
  }

  // Inicializar todos los datos necesarios
  Future<void> _initializeData() async {
    await _cargarDatosUsuario();
    if (isUserLoggedIn) {
      await Future.wait([
        _cargarHabilidadesUsuario(),
        _cargarTodasHabilidades(),
        _cargarCalificacionUsuario(),
        _cargarTrabajosRecientes(),
        _loadUserCategoriesAndOficios(),
        _loadUserLocation(),
      ]);
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      // Usando la API de Nominatim (OpenStreetMap) - es gratuita
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=es';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'TuApp/1.0', // Requerido por Nominatim
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['address'] != null) {
          final address = data['address'];

          // Extraer información relevante
          final String city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              'Ciudad desconocida';

          final String region = address['state'] ??
              address['region'] ??
              'Región desconocida';

          final String country = address['country'] ?? 'País desconocido';

          return '$city, $region, $country';
        }
      }

      // Si falla, devolver coordenadas como respaldo
      return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';

    } catch (e) {
      debugPrint('Error en geocodificación: $e');
      return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
    }
  }

  Future<void> _loadUserLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _currentLocationAddress = 'Ubicación no disponible';
          _isLoadingLocation = false;
        });
        return;
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

        // AQUÍ ESTÁ EL CAMBIO PRINCIPAL - usar geocodificación
        final address = await _getAddressFromCoordinates(lat, lng);

        setState(() {
          _currentLocationAddress = address;
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _currentLocationAddress = 'Ubicación no configurada';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ubicación: $e');
      setState(() {
        _currentLocationAddress = 'Error al cargar ubicación';
        _isLoadingLocation = false;
      });
    }
  }

  // Método para navegar a la pantalla de ubicación:
  void _navigateToUpdateLocation() async {
    if (kDebugMode) {
      print('🔵 INICIO - Botón de ubicación presionado');
    }

    try {
      final user = supabase.auth.currentUser;
      if (kDebugMode) {
        print('🔵 Usuario actual: ${user?.id}');
      }

      if (user == null) {
        if (kDebugMode) {
          print('🔴 ERROR: Usuario no autenticado');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para cambiar ubicación'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (kDebugMode) {
        print('🔵 Cargando ubicación actual del usuario...');
      }
      // Cargar la ubicación actual del usuario
      final locationData = await supabase
          .schema('jobs')
          .from('worker_locations')
          .select('latitud, longitud')
          .eq('user_id', user.id)
          .eq('user_type', 'worker')
          .maybeSingle();

      LatLng? initialPosition;
      if (locationData != null) {
        if (kDebugMode) {
          print('🔵 Ubicación encontrada en DB: $locationData');
        }
        final lat = locationData['latitud'] is String
            ? double.parse(locationData['latitud'])
            : locationData['latitud'].toDouble();
        final lng = locationData['longitud'] is String
            ? double.parse(locationData['longitud'])
            : locationData['longitud'].toDouble();

        initialPosition = LatLng(lat, lng);
        if (kDebugMode) {
          print('🔵 Posición inicial: $initialPosition');
        }
      } else {
        if (kDebugMode) {
          print('🔵 No hay ubicación guardada, usando por defecto');
        }
      }

      if (kDebugMode) {
        print('🔵 Navegando a UpdateLocationScreen...');
      }
      if (kDebugMode) {
        print('🔵 Context mounted: ${context.mounted}');
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            if (kDebugMode) {
              print('🔵 Construyendo UpdateLocationScreen');
            }
            return UpdateLocationScreen(
              initialPosition: initialPosition,
            );
          },
        ),
      );

      if (kDebugMode) {
        print('🔵 Regresé de UpdateLocationScreen con resultado: $result');
      }

      // Si se actualizó la ubicación, recargar la información
      if (result != null) {
        if (kDebugMode) {
          print('🔵 Recargando ubicación del usuario...');
        }
        await _loadUserLocation();
        if (kDebugMode) {
          print('🔵 Ubicación recargada exitosamente');
        }
      }

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔴 ERROR COMPLETO: $e');
      }
      if (kDebugMode) {
        print('🔴 STACK TRACE: $stackTrace');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ubicación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // MÉTODOS DE CARGA DE DATOS
  Future<void> _cargarDatosUsuario() async {
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        final userData = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl, descripcion, role')
            .eq('id', user.id)
            .single();

        setState(() {
          firstName = userData['firstName'];
          lastName = userData['lastName'];
          imageUrl = userData['imageUrl'];
          descripcion = userData['descripcion'] ?? 'Sin descripción';

          // DETECTAR SI ES TRABAJADOR
          final role = userData['role'] as String?;
          _isWorker = (role == 'worker');

          _descripcionController.text = descripcion!;
          isLoading = false;
          isUserLoggedIn = true;
        });
      } else {
        setState(() {
          isLoading = false;
          isUserLoggedIn = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos del usuario: $e');
      setState(() {
        isLoading = false;
        isUserLoggedIn = false;
      });
    }
  }

  Future<void> _cargarTrabajosRecientes() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoadingTrabajos = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingTrabajos = false);
        return;
      }

      // Obtener trabajos donde soy el proveedor (sender_id)
      final trabajosComoProveedor = await supabase
          .schema('jobs')
          .from('budget_proposals')
          .select('id, description, completed_at, amount, room_id, receiver_id, sender_id')
          .eq('sender_id', user.id)
          .eq('is_completed', true)
          .order('completed_at', ascending: false);

      // Obtener trabajos donde soy el cliente (receiver_id)
      final trabajosComoCliente = await supabase
          .schema('jobs')
          .from('budget_proposals')
          .select('id, description, completed_at, amount, room_id, receiver_id, sender_id')
          .eq('receiver_id', user.id)
          .eq('is_completed', true)
          .order('completed_at', ascending: false);

      // Combinar ambos tipos de trabajos
      final todosLosTrabajos = <Map<String, dynamic>>[];

      // Procesar trabajos como proveedor
      for (var trabajo in trabajosComoProveedor) {
        try {
          // Obtener datos del cliente
          final clienteData = await supabase
              .schema('chats')
              .from('users')
              .select('firstName, lastName')
              .eq('id', trabajo['receiver_id'])
              .single();

          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'proveedor',
            'titulo': trabajo['description'] ?? 'Servicio prestado',
            'cliente_nombre': '${clienteData['firstName'] ?? ''} ${clienteData['lastName'] ?? ''}'.trim(),
            'mostrar_como': 'Servicio prestado a ${clienteData['firstName'] ?? 'Cliente'}',
          });
        } catch (e) {
          debugPrint('Error obteniendo datos del cliente: $e');
          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'proveedor',
            'titulo': trabajo['description'] ?? 'Servicio prestado',
            'cliente_nombre': 'Cliente',
            'mostrar_como': 'Servicio prestado',
          });
        }
      }

      // Procesar trabajos como cliente
      for (var trabajo in trabajosComoCliente) {
        try {
          // Obtener datos del proveedor
          final proveedorData = await supabase
              .schema('chats')
              .from('users')
              .select('firstName, lastName')
              .eq('id', trabajo['sender_id'])
              .single();

          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'cliente',
            'titulo': trabajo['description'] ?? l10n.serviceContracted,
            'proveedor_nombre': '${proveedorData['firstName'] ?? ''} ${proveedorData['lastName'] ?? ''}'.trim(),
          });
        } catch (e) {
          debugPrint('Error obteniendo datos del proveedor: $e');
          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'cliente',
            'titulo': trabajo['description'] ?? l10n.serviceContracted,
            'proveedor_nombre': 'Proveedor',
          });
        }
      }

      // Ordenar todos los trabajos por fecha de finalización (más recientes primero)
      todosLosTrabajos.sort((a, b) {
        final fechaA = DateTime.parse(a['completed_at']);
        final fechaB = DateTime.parse(b['completed_at']);
        return fechaB.compareTo(fechaA);
      });

      // Tomar solo los 3 más recientes
      final trabajosLimitados = todosLosTrabajos.take(3).toList();

      setState(() {
        _trabajosRecientes = trabajosLimitados;
        _isLoadingTrabajos = false;
      });

    } catch (e) {
      debugPrint('Error al cargar trabajos recientes: $e');
      setState(() => _isLoadingTrabajos = false);
    }
  }

  Future<void> _cargarHabilidadesUsuario() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .select('habilidad_id, nivel, habilidades:habilidad_id(id, name)')
          .eq('user_id', user.id);

      final skills = <Map<String, dynamic>>[];
      for (var item in data) {
        if (item['habilidades'] != null) {
          skills.add({
            'id': item['habilidad_id'],
            'name': item['habilidades']['name'],
            'nivel': item['nivel'] ?? 'Intermedio',
          });
        }
      }

      setState(() => userSkills = skills);
    } catch (e) {
      debugPrint('Error al cargar habilidades del usuario: $e');
    }
  }

  Future<void> _cargarTodasHabilidades() async {
    try {
      final data = await supabase
          .schema('jobs')
          .from('habilidades')
          .select('id, name')
          .limit(100);

      setState(() => allSkills = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error al cargar todas las habilidades: $e');
    }
  }

  Future<void> _cargarCalificacionUsuario() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final rating = await ReviewService.getUserRatingOptimized(user.id);

      setState(() {
        userRating = rating;
        averageRating = rating.averageRating;
        totalReviews = rating.totalReviews;
        isLoadingReviews = false;
      });
    } catch (e) {
      debugPrint('Error al cargar calificación del usuario: $e');
      setState(() => isLoadingReviews = false);
    }
  }

  Future<void> _loadUserCategoriesAndOficios() async {
    try {
      final result = await _userService.getUserCategoriesWithOficios();
      setState(() {
        _userCategories = result['categories'] ?? [];
        _userOficios = result['oficiosPorCategoria'] ?? {};
      });
    } catch (e) {
      debugPrint('Error loading categories and oficios: $e');
    }
  }

  // MÉTODOS DE ACTUALIZACIÓN
  Future<void> _actualizarDescripcion(String nuevaDescripcion) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .schema('chats')
          .from('users')
          .update({'descripcion': nuevaDescripcion})
          .eq('id', user.id);

      setState(() => descripcion = nuevaDescripcion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descripción actualizada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  // Método mejorado para actualizar foto de perfil con múltiples opciones
  Future<void> _actualizarFotoPerfil() async {
    // Mostrar dialog con opciones
    final option = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
          title: const Text('Seleccionar foto'),
          content: const Text('¿Cómo te gustaría seleccionar tu foto?'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Cámara'),
              onPressed: () => Navigator.of(context).pop('camera'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Galería'),
              onPressed: () => Navigator.of(context).pop('gallery'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Explorador'),
              onPressed: () => Navigator.of(context).pop('files'),
            ),
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
    );

    if (option == null) return;

    final picker = ImagePicker();
    XFile? imagen;

    try {
      switch (option) {
        case 'camera':
          imagen = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
          break;

        case 'gallery':
          imagen = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
          break;

        case 'files':
        // Para dispositivos antiguos, usar el explorador de archivos
          imagen = await _pickImageFromFiles();
          break;
      }

      if (imagen == null) return;

      await _procesarImagenSeleccionada(imagen);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método alternativo usando file_picker para dispositivos antiguos
  Future<XFile?> _pickImageFromFiles() async {
    try {
      // Necesitarás agregar file_picker a pubspec.yaml
      // file_picker: ^6.1.1

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false, // Para mejor rendimiento en dispositivos antiguos
      );

      if (result != null && result.files.single.path != null) {
        return XFile(result.files.single.path!);
      }

      return null;

    } catch (e) {
      debugPrint('Error con file_picker: $e');

      // Fallback: Intentar con image_picker con configuración más compatible
      final picker = ImagePicker();
      return await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Reducir resolución para dispositivos antiguos
        maxHeight: 800,
        imageQuality: 70,
      );
    }
  }

  // Método para procesar la imagen seleccionada (común para todas las opciones)
  Future<void> _procesarImagenSeleccionada(XFile imagen) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Subiendo imagen...'),
              ],
            ),
          ),
        );
      }

      // Verificar el tamaño del archivo
      final file = File(imagen.path);
      final fileSize = await file.length();

      // Si el archivo es muy grande (>2MB), comprimirlo más
      XFile finalImage = imagen;
      if (fileSize > 2 * 1024 * 1024) {
        finalImage = await _compressImage(imagen);
      }

      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}${path.extension(finalImage.path)}';
      final storageUrl = 'user_profiles/$fileName';

      final finalFile = File(finalImage.path);
      await supabase.storage.from('profile_images').upload(storageUrl, finalFile);

      final publicUrl = supabase.storage.from('profile_images').getPublicUrl(storageUrl);

      await supabase
          .schema('chats')
          .from('users')
          .update({'imageUrl': publicUrl})
          .eq('id', user.id);

      setState(() => imageUrl = publicUrl);

      if (mounted) {
        Navigator.pop(context); // Cerrar dialog de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar dialog de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para comprimir imagen en dispositivos antiguos
  Future<XFile> _compressImage(XFile image) async {
    try {

      final file = File(image.path);
      final bytes = await file.readAsBytes();

      // Decodificar imagen
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return image;

      // Redimensionar si es necesario (máximo 800x800)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 800 || originalImage.height > 800) {
        resizedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? 800 : null,
          height: originalImage.height > originalImage.width ? 800 : null,
        );
      }

      // Comprimir como JPEG con calidad 70
      final compressedBytes = img.encodeJpg(resizedImage, quality: 70);

      // Crear archivo temporal
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return XFile(tempFile.path);

    } catch (e) {
      debugPrint('Error comprimiendo imagen: $e');
      return image; // Retornar imagen original si falla la compresión
    }
  }

  // También puedes agregar este método alternativo más simple para dispositivos muy antiguos
  Future<void> _actualizarFotoPerfilSimple() async {
    try {
      final picker = ImagePicker();

      // Usar configuración más compatible para dispositivos antiguos
      final imagen = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 60,
        requestFullMetadata: false, // Menos metadatos para mayor compatibilidad
      );

      if (imagen != null) {
        await _procesarImagenSeleccionada(imagen);
      }

    } catch (e) {
      // Si falla, intentar con configuración aún más básica
      try {
        final picker = ImagePicker();
        final imagen = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
        );

        if (imagen != null) {
          await _procesarImagenSeleccionada(imagen);
        }

      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu dispositivo no es compatible con esta función. Contacta soporte.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  // MÉTODOS DE HABILIDADES
  Future<List<Map<String, dynamic>>> _buscarHabilidades(String query) async {
    try {
      final data = await supabase
          .schema('jobs')
          .from('habilidades')
          .select('id, name')
          .ilike('name', '%$query%')
          .limit(10);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error al buscar habilidades: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _crearNuevaHabilidad(String skillName) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final result = await supabase
          .schema('jobs')
          .from('habilidades')
          .insert({
        'name': skillName,
        'user_id': user.id,
      })
          .select()
          .single();

      return result;
    } catch (e) {
      debugPrint('Error al crear nueva habilidad: $e');
      return null;
    }
  }

  Future<void> _agregarHabilidadUsuario(int habilidadId, String nivel) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Verificar si ya existe
      final existingSkills = await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .select()
          .eq('habilidad_id', habilidadId)
          .eq('user_id', user.id);

      if (existingSkills.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya tienes esta habilidad en tu perfil')),
          );
        }
        return;
      }

      await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .insert({
        'habilidad_id': habilidadId,
        'user_id': user.id,
        'habilidades_id': habilidadId,
        'nivel': nivel,
      });

      await _cargarHabilidadesUsuario();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilidad agregada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agregar habilidad: $e')),
        );
      }
    }
  }

  Future<void> _eliminarHabilidadUsuario(int habilidadId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .delete()
          .eq('habilidad_id', habilidadId)
          .eq('user_id', user.id);

      setState(() {
        userSkills.removeWhere((skill) => skill['id'] == habilidadId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilidad eliminada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar habilidad: $e')),
        );
      }
    }
  }

  // MÉTODOS DE AUTENTICACIÓN
  Future<void> logout() async {
    try {
      await supabase.auth.signOut();

      setState(() {
        isUserLoggedIn = false;
        firstName = '';
        lastName = '';
        imageUrl = 'https://placehold.co/100';
        descripcion = '';
      });

      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const AuthScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  // MÉTODOS DE UI
  void _mostrarDialogoAgregarHabilidad() {
  var searchResults = <Map<String, dynamic>>[];
  var isSearching = false;
  var nivel = 'Intermedio'; // Valor por defecto

  showDialog(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Agregar habilidad'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- CAMPO DE BÚSQUEDA ---
              TextField(
                controller: _searchSkillController,
                decoration: const InputDecoration(
                  hintText: 'Buscar habilidad...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) async {
                  if (value.length >= 2) {
                    setDialogState(() => isSearching = true);
                    final results = await _buscarHabilidades(value);
                    setDialogState(() {
                      searchResults = results;
                      isSearching = false;
                    });
                  } else {
                    setDialogState(() => searchResults = []);
                  }
                },
              ),
              const SizedBox(height: 15),

              // --- DROPDOWN DE NIVEL ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Nivel',
                  border: OutlineInputBorder(),
                ),
                value: nivel,
                items: nivelesHabilidad.map((nivelItem) => DropdownMenuItem<String>(
                  value: nivelItem,
                  child: Text(nivelItem),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => nivel = value);
                  }
                },
              ),
              const SizedBox(height: 15),

              // --- LISTA DE RESULTADOS ---
              if (isSearching)
                const Center(child: CircularProgressIndicator())
              else if (searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final skill = searchResults[index];
                      
                      // CORRECCIÓN: Aquí mostramos directamente el nombre de la habilidad.
                      // No necesitamos lógica de traducción de "Cliente/Proveedor" aquí.
                      return ListTile(
                        leading: const Icon(Icons.handyman_outlined), // Icono decorativo opcional
                        title: Text(skill['name'] ?? 'Habilidad sin nombre'),
                        subtitle: Text('Nivel seleccionado: $nivel'),
                        onTap: () async {
                          // Al tocar, agregamos la habilidad
                          await _agregarHabilidadUsuario(skill['id'], nivel);
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    },
                  ),
                )
              // --- OPCIÓN DE CREAR NUEVA SI NO EXISTE ---
              else if (_searchSkillController.text.isNotEmpty)
                Column(
                  children: [
                    const Text('No se encontraron resultados'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        setDialogState(() => isSearching = true);
                        try {
                          final newSkill = await _crearNuevaHabilidad(_searchSkillController.text);
                          if (newSkill != null) {
                            await _agregarHabilidadUsuario(newSkill['id'], nivel);
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isSearching = false);
                          }
                        }
                      },
                      child: const Text('Crear nueva habilidad'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ),
  ).then((_) => _searchSkillController.clear());
}

  void _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          userProfile: {
            'firstName': firstName,
            'lastName': lastName,
            'email': supabase.auth.currentUser?.email,
            'imageUrl': imageUrl,
            'descripcion': descripcion,
          },
          onProfileUpdated: () {
            _initializeData();
          },
        ),
      ),
    );

    if (result == true) {
      await _initializeData();
    }
  }

  void _navigateToUpdateCategories(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UpdateCategoriesScreen(),
      ),
    );

    if (result == true && widget.onProfileUpdated != null) {
      widget.onProfileUpdated!();
    }
  }

  Widget _buildNoSessionWidget() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'No has iniciado sesión',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Inicia sesión para ver tu perfil',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => const AuthScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Iniciar Sesión'),
        ),
      ],
    ),
  );

  Widget _buildSkillChip(String skill, {required String nivel, VoidCallback? onDeleted}) => Chip(
      label: Text(skill, style: const TextStyle(color: Color(0xFF2563EB))),
      backgroundColor: const Color(0xFFEFF6FF),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );

  @override
  Widget build(BuildContext context) {
      final l10n = AppLocalizations.of(context)!;
      
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileTitle),
          centerTitle: false,
          elevation: 2,
          actions: [
            if (isUserLoggedIn)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _navigateToSettings,
              ),
          ],
        ),
        backgroundColor: Colors.white,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : !isUserLoggedIn
            ? _buildNoSessionWidget()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Foto de perfil
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(imageUrl ?? 'https://placehold.co/100'),
                    onBackgroundImageError: (_, __) => const Icon(Icons.error),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _actualizarFotoPerfil,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Información básica
              Text(
                '$firstName $lastName',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),

              // Calificaciones
              isLoadingReviews
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '($totalReviews ${totalReviews == 1 ? 'review' : 'reviews'})',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Descripción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.aboutMe, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(_isEditingDescription ? Icons.check : Icons.edit, size: 18),
                    onPressed: () {
                      if (_isEditingDescription) {
                        _actualizarDescripcion(_descripcionController.text);
                      }
                      setState(() => _isEditingDescription = !_isEditingDescription);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 5),

              _isEditingDescription
                  ? TextField(
                controller: _descripcionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe algo sobre ti...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              )
                  : Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  descripcion ?? 'Sin descripción',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),

              // Habilidades
              if (_isWorker) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.skills, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _mostrarDialogoAgregarHabilidad,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...userSkills.map((skill) => _buildSkillChip(
                      skill['name'],
                      nivel: skill['nivel'],
                      onDeleted: () => _eliminarHabilidadUsuario(skill['id']),
                    ),
                    ),
                    if (userSkills.isEmpty)
                      Text(l10n.noAddedSkills, style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
              
              _buildLocationSection(),
              const SizedBox(height: 15),

              // Categorías y oficios
              if (_isWorker && _userCategories.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.specialties, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _navigateToUpdateCategories(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._userCategories.map((category) {
                  final categoryId = category['id'] as int;
                  final oficios = _userOficios[categoryId] ?? [];

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.category, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (oficios.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: oficios.map((oficio) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue.shade300),
                              ),
                              child: Text(
                                oficio['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 15),
              ],

              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: [
                  Tab(text: l10n.jobs),
                  Tab(text: l10n.comments),
                  Tab(text: l10n.settings),
                ],
              ),

              // Contenido de tabs
              Container(
                constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(child: _buildTrabajos()),
                    isLoadingReviews
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(child: _buildComentarios()),
                    SingleChildScrollView(child: _buildAjustes()),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      }

  // WIDGETS DE TABS
  Widget _buildTrabajos() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_isLoadingTrabajos) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_trabajosRecientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.work_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                l10n.noCompletedJobs,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.completedJobs,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 1. Obtener idioma actual
    final currentLocale = Localizations.localeOf(context).languageCode;

    // 2. Formato de fecha automático (Ej: "14 de febrero de 2024" o "February 14, 2024")
    final dateFormat = DateFormat.yMMMMd(currentLocale);
    
    // 3. Moneda adaptada al idioma
    final moneyFormat = NumberFormat.currency(
      locale: currentLocale, 
      symbol: '\$',
      decimalDigits: 0,
    );

    return Column(
      children: [
        ..._trabajosRecientes.map((trabajo) {
          final fecha = trabajo['completed_at'] != null
              ? DateTime.parse(trabajo['completed_at'])
              : DateTime.now();

          final esProveedor = trabajo['tipo'] == 'proveedor';
          
          // --- AQUÍ ESTÁ LA CORRECCIÓN ---
          // Construimos los textos dinámicamente usando l10n
          String tituloPrincipal;
          String subtituloUsuario;

          if (esProveedor) {
            // Soy el trabajador
            tituloPrincipal = trabajo['description'] ?? 'Servicio prestado';
            // Puedes agregar un l10n.serviceProvidedTo si quieres traducirlo también
            subtituloUsuario = 'Servicio prestado a ${trabajo['cliente_nombre'] ?? 'Cliente'}';
          } else {
            // Soy el cliente
            tituloPrincipal = trabajo['description'] ?? l10n.serviceContracted;
            // Aquí usamos la traducción que faltaba: "Service of..."
            subtituloUsuario = '${l10n.serviceOf} ${trabajo['proveedor_nombre'] ?? 'Proveedor'}';
          }

          final monto = trabajo['amount'] != null
              ? moneyFormat.format(trabajo['amount'])
              : '';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: esProveedor ? Colors.green.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  esProveedor ? Icons.build : Icons.shopping_cart,
                  color: esProveedor ? Colors.green.shade700 : Colors.blue.shade700,
                  size: 24,
                ),
              ),
              title: Text(
                tituloPrincipal, // Usamos la variable calculada arriba
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  // Agregamos el texto de "Servicio de..." que faltaba
                  Text(
                    subtituloUsuario,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.completed} ${dateFormat.format(fecha)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  if (monto.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      monto,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: esProveedor ? Colors.green.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  esProveedor ? 'Prestado' : l10n.contracted,
                  style: TextStyle(
                    color: esProveedor ? Colors.green.shade700 : Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TrabajosScreen()),
              );
            },
            icon: const Icon(Icons.work),
            label: Text(l10n.showAllWork),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComentarios() {
    final l10n = AppLocalizations.of(context)!;
    debugPrint('🔍 _buildComentarios - userRating: $userRating');
    debugPrint('🔍 _buildComentarios - totalReviews: ${userRating?.totalReviews}');
    debugPrint('🔍 _buildComentarios - reviews length: ${userRating?.reviews.length}');

    if (userRating == null || userRating!.totalReviews == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.comment_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noCommentsAvaliable,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.allCommentsOfUsers,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ✅ MOSTRAR SOLO LOS 3 MÁS RECIENTES
    final reviewsToShow = userRating!.reviews.take(3).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          ...reviewsToShow.asMap().entries.map((entry) {
            final index = entry.key;
            final review = entry.value;
            
            final currentLocale = Localizations.localeOf(context).languageCode;
            final dateFormat = DateFormat.yMMMMd(currentLocale); // Fecha larga automática

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con usuario y fecha
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: review.reviewerData?['imageUrl'] != null
                                ? NetworkImage(review.reviewerData!['imageUrl'])
                                : null,
                            child: review.reviewerData?['imageUrl'] == null
                                ? const Icon(Icons.person, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${review.reviewerData?['firstName'] ?? 'Usuario'} ${review.reviewerData?['lastName'] ?? ''}'.trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  dateFormat.format(review.createdAt.toLocal()),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Rating con estrellas
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List.generate(5, (starIndex) => Icon(
                                    starIndex < review.rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${review.rating}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Comentario
                      if (review.comment.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            review.comment,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Separador entre comentarios (excepto el último)
                if (index < reviewsToShow.length - 1)
                  const Divider(height: 1),
              ],
            );
          }).toList(),

          // ✅ BOTÓN PARA VER TODAS LAS RESEÑAS (mostrar siempre si hay reseñas)
          if (userRating!.totalReviews > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ReviewsScreen(
                        userId: supabase.auth.currentUser!.id,
                        userRating: userRating!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.comment),
                label: Text('Ver todas las reseñas (${userRating!.totalReviews})'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(){
    final l10n = AppLocalizations.of(context)!;
    return Column(children: [
      const SizedBox(height: 15),

      // SECCIÓN EXCLUSIVA DE TRABAJADOR (Agenda y Switch)
      if (isUserLoggedIn && _isWorker) ...[
        const WorkerStatusSwitch(),
        
        const SizedBox(height: 12),
        
        // Botón de Agenda
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WorkerScheduleScreen()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.scheduleWeek,
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.scheduleWeekSubtitle,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WorkerAgendaScreen()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50, 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.event_note, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.scheduledVisits,
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.scheduledVisitsSubtitle,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24), // Espacio separador
      ],

      // SECCIÓN COMÚN (Ubicación - visible para todos para envíos/referencia)
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.location,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.edit_location),
            onPressed: () => _navigateToUpdateLocation(),
          ),
        ],
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => _navigateToUpdateLocation(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentLocation, // Texto genérico para ambos roles
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingLocation
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            _currentLocationAddress,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    ],
  );
  }

  Widget _buildAjustes(){
    final l10n = AppLocalizations.of(context)!;
    return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Cuenta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
        ListTile(
        leading: const Icon(Icons.person),
        title: Text(l10n.personalInfo),
        subtitle: Text(l10n.updatePersonalInfo),
        trailing: const Icon(Icons.chevron_right),
        onTap: _navigateToSettings,
      ),
      if (_isWorker) ...[
        ListTile(
          leading: const Icon(Icons.work),
          title: Text(l10n.specialties),
          subtitle: Text(l10n.updateSpecialties),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _navigateToUpdateCategories(context),
        ),
        const Divider(),
      ],
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: Text(l10n.logout, style: TextStyle(color: Colors.red)),
        onTap: logout,
      ),
    ],
  );
}
}