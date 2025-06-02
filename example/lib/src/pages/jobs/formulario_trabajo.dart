import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http_client; // ✅ CORREGIDO: Alias para http
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase_options.dart';

class FormularioTrabajo extends StatefulWidget {
  const FormularioTrabajo({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FormularioTrabajoState createState() => _FormularioTrabajoState();
}

class _FormularioTrabajoState extends State<FormularioTrabajo> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _selectedPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  File? _selectedImage;
  String _selectedLocationAddress = 'Cargando ubicación...';
  bool _isLoadingAddress = true;

  // Variables para búsqueda de categorías
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingCategories = false;
  String? _categoriaSeleccionada;
  int? _categoriaSeleccionadaId;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _searchCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserSavedLocation();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _montoController.dispose();
    _searchCategoryController.dispose();
    super.dispose();
  }

  // ✅ MÉTODO CORREGIDO para geocodificación inversa:
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      // Usando la API de Nominatim (OpenStreetMap) - es gratuita
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=es';

      final response = await http_client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'TuApp/1.0', // Requerido por Nominatim
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

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

  // ✅ MÉTODO para actualizar la dirección:
  Future<void> _updateLocationAddress(LatLng position) async {
    setState(() => _isLoadingAddress = true);

    try {
      final address = await _getAddressFromCoordinates(
          position.latitude,
          position.longitude,
      );

      setState(() {
        _selectedLocationAddress = address;
        _isLoadingAddress = false;
      });
    } catch (e) {
      setState(() {
        _selectedLocationAddress = 'Error al cargar dirección';
        _isLoadingAddress = false;
      });
    }
  }

  // ✅ MÉTODO CORREGIDO para cargar ubicación guardada:
  Future<void> _loadUserSavedLocation() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        await _getCurrentLocation();
        return;
      }

      // Intentar cargar la ubicación guardada del usuario
      final locationData = await Supabase.instance.client
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

        final position = LatLng(lat, lng);

        setState(() {
          _selectedPosition = position;
          _currentPosition = _selectedPosition;
          _isLoading = false;
        });

        // ✅ NUEVO: Cargar la dirección
        await _updateLocationAddress(position);

        if (kDebugMode) {
          print('✅ Ubicación guardada cargada: $lat, $lng');
        }
      } else {
        // No hay ubicación guardada, usar ubicación actual
        await _getCurrentLocation();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error cargando ubicación guardada: $e');
      }
      // Fallback a ubicación actual
      await _getCurrentLocation();
    }
  }

  // ✅ MÉTODO CORREGIDO para obtener ubicación actual:
  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Servicios de ubicación deshabilitados');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _errorMessage = 'Permiso de ubicación denegado');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentPos = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = currentPos;
        _selectedPosition ??= _currentPosition;
        _isLoading = false;
      });

      // ✅ NUEVO: Cargar la dirección si no hay posición seleccionada previa
      if (_selectedPosition == currentPos) {
        await _updateLocationAddress(currentPos);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al obtener ubicación: $e';
        _isLoading = false;
      });
    }
  }

  // ✅ MÉTODO CORREGIDO para abrir selector de ubicación:
  Future<void> _openLocationPicker() async {
    if (_selectedPosition == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialPosition: _selectedPosition!,
          currentUserPosition: _currentPosition,
        ),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() {
        _selectedPosition = result;
      });

      // Mover el mapa a la nueva posición
      _mapController.move(result, 18);

      // ✅ NUEVO: Actualizar la dirección
      await _updateLocationAddress(result);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Ubicación de trabajo actualizada'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Buscar categorías en tiempo real
  Future<void> _searchCategories(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearchingCategories = true);

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .schema('jobs')
          .from('categories')
          .select('id, name')
          .ilike('name', '%$query%')
          .order('name')
          .limit(10);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(data);
        _isSearchingCategories = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al buscar categorías: $e');
      }
      setState(() {
        _searchResults = [];
        _isSearchingCategories = false;
      });
    }
  }

  // Seleccionar una categoría
  void _selectCategory(Map<String, dynamic> category) {
    setState(() {
      _categoriaSeleccionada = category['name'];
      _categoriaSeleccionadaId = category['id'];
      _searchCategoryController.text = category['name'];
      _searchResults = [];
    });
  }

  void initializeSupabase() {
    Supabase.initialize(
      url: supabaseOptions.url,
      anonKey: supabaseOptions.anonKey,
    );
  }

  Future<void> _saveLocationToSupabase(double lat, double lon, String? imageUrl) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showErrorMessage('Usuario no autenticado');
      return;
    }

    if (_categoriaSeleccionadaId == null) {
      _showErrorMessage('Debe seleccionar una categoría');
      return;
    }

    final location = 'POINT($lon $lat)';

    try {
      await supabase.schema('jobs').from('offers').insert({
        'user_id': user.id,
        'name': _tituloController.text,
        'category_id': _categoriaSeleccionadaId,
        'amount': _montoController.text,
        'description': _descripcionController.text,
        'image_url': imageUrl,
        'location': location,
      });

      // Mostrar mensaje de éxito
      _showSuccessMessage('¡Trabajo publicado exitosamente!');

      // Limpiar formulario
      _clearForm();

      // ✅ NUEVO: Volver al home (TrabajoPage) después de un delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Navegar de vuelta al home y quitar todas las pantallas anteriores
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/main', // Ruta del MainScreen que contiene TrabajoPage
                (route) => false, // Eliminar todas las rutas anteriores
          );
        }
      });

    } catch (e) {
      _showErrorMessage('Error al guardar: $e');
    }
  }

  // ✅ MÉTODO CORREGIDO para mostrar mensaje de éxito
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Nuevo método para mostrar mensaje de error
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.error,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Nuevo método para limpiar el formulario
  void _clearForm() {
    setState(() {
      // Limpiar controladores de texto
      _tituloController.clear();
      _descripcionController.clear();
      _montoController.clear();
      _searchCategoryController.clear();

      // Resetear variables de categoría
      _categoriaSeleccionada = null;
      _categoriaSeleccionadaId = null;
      _searchResults = [];

      // Limpiar imagen seleccionada
      _selectedImage = null;

      // Resetear posición a la ubicación actual
      _selectedPosition = _currentPosition;

      // Limpiar mensaje de error
      _errorMessage = '';
    });

    // Mover el mapa de vuelta a la ubicación actual
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 18);
    }
  }

  Future<void> _pickImage() async {
    // Mostrar dialog con opciones
    final option = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
        content: const Text('¿Cómo te gustaría seleccionar la imagen del trabajo?'),
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
          imagen = await _pickImageFromFiles();
          break;
      }

      if (imagen != null) {
        await _procesarImagenSeleccionada(imagen);
      }

    } catch (e) {
      if (mounted) {
        _showErrorMessage('Error al seleccionar imagen: $e');
      }
    }
  }

  // Método alternativo para dispositivos antiguos
  Future<XFile?> _pickImageFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.single.path != null) {
        return XFile(result.files.single.path!);
      }

      return null;

    } catch (e) {
      debugPrint('Error con file_picker: $e');

      // Fallback a image_picker básico
      final picker = ImagePicker();
      return await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
    }
  }

  // Procesar imagen seleccionada
  Future<void> _procesarImagenSeleccionada(XFile imagen) async {
    try {
      // Verificar tamaño del archivo
      final file = File(imagen.path);
      final fileSize = await file.length();

      // Si es muy grande (>2MB), comprimir
      var finalImage = imagen;
      if (fileSize > 2 * 1024 * 1024) {
        finalImage = await _compressImage(imagen);
      }

      setState(() {
        _selectedImage = File(finalImage.path);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen seleccionada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al procesar imagen: $e');
      }
      if (mounted) {
        _showErrorMessage('Error al procesar imagen: $e');
      }
    }
  }

  // Comprimir imagen para dispositivos antiguos
  Future<XFile> _compressImage(XFile image) async {
    try {
      final file = File(image.path);
      final bytes = await file.readAsBytes();

      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return image;

      // Redimensionar si es necesario
      var resizedImage = originalImage;
      if (originalImage.width > 800 || originalImage.height > 800) {
        resizedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? 800 : null,
          height: originalImage.height > originalImage.width ? 800 : null,
        );
      }

      // Comprimir como JPEG
      final compressedBytes = img.encodeJpg(resizedImage, quality: 70);

      // Crear archivo temporal
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/compressed_work_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return XFile(tempFile.path);

    } catch (e) {
      debugPrint('Error comprimiendo imagen: $e');
      return image;
    }
  }

  // Método simple para dispositivos muy antiguos
  Future<void> _pickImageSimple() async {
    try {
      final picker = ImagePicker();
      final imagen = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 60,
        requestFullMetadata: false,
      );

      if (imagen != null) {
        await _procesarImagenSeleccionada(imagen);
      }

    } catch (e) {
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
          _showErrorMessage('Tu dispositivo no es compatible con esta función. Contacta soporte.');
        }
      }
    }
  }

  Future<String?> _uploadImageToSupabase(File? imageFile) async {
    if (imageFile == null) return null;

    try {
      final fileName = 'trabajo_${DateTime.now().millisecondsSinceEpoch}.png';

      final bytes = await imageFile.readAsBytes();

      final supabaseClient = Supabase.instance.client;

      await supabaseClient.storage.from('jobs_offers_images').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(upsert: true),
      );

      return supabaseClient.storage.from('jobs_offers_images').getPublicUrl(fileName);
    } on StorageException catch (error) {
      if (kDebugMode) {
        print('Supabase Storage Error: ${error.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Upload error: $e');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Formulario de Trabajo')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _tituloController,
            decoration: const InputDecoration(labelText: 'Título del trabajo'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descripcionController,
            decoration: const InputDecoration(labelText: 'Descripción'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _montoController,
            decoration: const InputDecoration(labelText: 'Monto'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Campo de búsqueda para categorías
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Buscar categoría...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _searchCategories(value);
                },
              ),
              const SizedBox(height: 8),

              // Resultados de búsqueda
              if (_isSearchingCategories)
                Container(
                  height: 60,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final category = _searchResults[index];
                      return ListTile(
                        title: Text(category['name']),
                        onTap: () => _selectCategory(category),
                      );
                    },
                  ),
                )
              else if (_searchCategoryController.text.length >= 2 && _categoriaSeleccionada == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'No se encontraron categorías. Intenta con otra búsqueda.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),

              // Mostrar categoría seleccionada
              if (_categoriaSeleccionada != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Categoría seleccionada: $_categoriaSeleccionada',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _categoriaSeleccionada = null;
                            _categoriaSeleccionadaId = null;
                            _searchCategoryController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ✅ Sección de imagen
          _buildImageSection(),

          const SizedBox(height: 20),

          // ✅ Sección del mapa
          _buildMapSection(),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Validaciones
                if (_tituloController.text.trim().isEmpty) {
                  _showErrorMessage('Por favor ingresa un título');
                  return;
                }

                if (_descripcionController.text.trim().isEmpty) {
                  _showErrorMessage('Por favor ingresa una descripción');
                  return;
                }

                if (_montoController.text.trim().isEmpty) {
                  _showErrorMessage('Por favor ingresa un monto');
                  return;
                }

                if (_categoriaSeleccionadaId == null) {
                  _showErrorMessage('Por favor selecciona una categoría');
                  return;
                }

                if (_selectedPosition == null) {
                  _showErrorMessage('Por favor selecciona una ubicación en el mapa');
                  return;
                }

                // Mostrar indicador de carga
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Publicando trabajo...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                try {
                  String? imageUrl;
                  if (_selectedImage != null) {
                    imageUrl = await _uploadImageToSupabase(_selectedImage!);
                  }

                  await _saveLocationToSupabase(
                    _selectedPosition!.latitude,
                    _selectedPosition!.longitude,
                    imageUrl,
                  );
                } finally {
                  // Cerrar diálogo de carga
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              icon: const Icon(Icons.publish),
              label: const Text(
                'Publicar Trabajo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ✅ Widget para la sección de imagen
  Widget _buildImageSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Imagen del trabajo',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),

      if (_selectedImage != null) ...[
        // Imagen seleccionada
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Botones para cambiar o remover imagen
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Cambiar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                });
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Remover', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),

        // Opción para dispositivos antiguos
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _pickImageSimple,
            icon: const Icon(Icons.phone_android),
            label: const Text('¿Problemas? Usa modo básico'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
          ),
        ),
      ] else ...[
        // No hay imagen seleccionada
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                size: 40,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 8),
              Text(
                'Agregar imagen del trabajo',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '(Opcional)',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Botones para seleccionar imagen
        Center(
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Seleccionar Imagen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickImageSimple,
                icon: const Icon(Icons.phone_android),
                label: const Text('¿Problemas? Usa modo básico'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  // ✅ Widget CORREGIDO para la sección del mapa
  Widget _buildMapSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Ubicación del trabajo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: _openLocationPicker,
            icon: const Icon(Icons.open_in_full),
            tooltip: 'Abrir selector de ubicación',
          ),
        ],
      ),
      const SizedBox(height: 8),

      // ✅ CORREGIDO: Información de la ubicación actual con dirección
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubicación seleccionada:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  _isLoadingAddress
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    _selectedLocationAddress,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openLocationPicker,
              child: const Text('Cambiar'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Mapa pequeño con preview
      Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _isLoading
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
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _getCurrentLocation,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
              : Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedPosition ?? _currentPosition!,
                  initialZoom: 16,
                  onTap: (tapPosition, point) {
                    // Mostrar un snackbar con instrucciones
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Mantén presionado para cambiar ubicación o usa el botón "Cambiar" arriba'),
                        action: SnackBarAction(
                          label: 'Abrir mapa',
                          onPressed: _openLocationPicker,
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  onLongPress: (tapPosition, point) async {
                    // ✅ CORREGIDO: Cambiar ubicación con long press y actualizar dirección
                    setState(() {
                      _selectedPosition = point;
                    });

                    // Actualizar dirección
                    await _updateLocationAddress(point);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📍 Ubicación actualizada'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onMapReady: () {
                    // Acciones adicionales cuando el mapa esté listo
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_selectedPosition != null)
                        Marker(
                          point: _selectedPosition!,
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

              // Overlay con instrucciones
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Mantén presionado para cambiar ubicación',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),

              // ✅ CORREGIDO: Botón para centrar en ubicación actual
              Positioned(
                bottom: 8,
                right: 8,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () async {
                    if (_currentPosition != null) {
                      _mapController.move(_currentPosition!, 16);
                      setState(() {
                        _selectedPosition = _currentPosition;
                      });

                      // ✅ NUEVO: Actualizar dirección
                      await _updateLocationAddress(_currentPosition!);
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),

              // Botón para abrir mapa grande
              Positioned(
                bottom: 8,
                left: 8,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _openLocationPicker,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.open_in_full, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ✅ NUEVA PANTALLA: Selector de ubicación de pantalla completa
class LocationPickerScreen extends StatefulWidget {
  final LatLng initialPosition;
  final LatLng? currentUserPosition;

  const LocationPickerScreen({
    super.key,
    required this.initialPosition,
    this.currentUserPosition,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _selectedPosition;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Función simple de búsqueda de lugares (usando Nominatim)
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Esta es una implementación básica usando Nominatim
      // En producción, podrías usar Google Places API o similar
      final response = await Future.delayed(
        const Duration(milliseconds: 500),
            () =>
        <Map<String, dynamic>>[
          {
            'display_name': 'Resultado de ejemplo para: $query',
            'lat': _selectedPosition.latitude + 0.001,
            'lon': _selectedPosition.longitude + 0.001,
          },
        ],
      );

      setState(() {
        _searchResults = response;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _moveToPosition(LatLng position) {
    setState(() => _selectedPosition = position);
    _mapController.move(position, 16);
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(
        appBar: AppBar(
          title: const Text('Seleccionar ubicación'),
          backgroundColor: Colors.blue,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedPosition);
              },
              child: const Text(
                'Confirmar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Barra de búsqueda
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar lugar...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: _searchPlaces,
              ),
            ),

            // Resultados de búsqueda
            if (_isSearching)
              const LinearProgressIndicator()
            else
              if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(result['display_name']),
                        onTap: () {
                          final lat = double.parse(result['lat'].toString());
                          final lon = double.parse(result['lon'].toString());
                          _moveToPosition(LatLng(lat, lon));
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      );
                    },
                  ),
                ),

            // Mapa
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPosition,
                      initialZoom: 16,
                      onTap: (tapPosition, point) {
                        setState(() => _selectedPosition = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(
                        markers: [
                          // Marcador de la posición seleccionada
                          Marker(
                            point: _selectedPosition,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 50,
                            ),
                          ),
                          // Marcador de la ubicación actual del usuario (si existe)
                          if (widget.currentUserPosition != null)
                            Marker(
                              point: widget.currentUserPosition!,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Información de coordenadas
                  Positioned(
                    bottom: 80,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Ubicación seleccionada:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Lat: ${_selectedPosition.latitude.toStringAsFixed(
                                6)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Lng: ${_selectedPosition.longitude.toStringAsFixed(
                                6)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botón para ir a ubicación actual
                  if (widget.currentUserPosition != null)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: () {
                          _moveToPosition(widget.currentUserPosition!);
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}