import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
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
  LatLng? _selectedPosition; // Nueva variable para la posición seleccionada
  bool _isLoading = true;
  String _errorMessage = '';
  File? _selectedImage;
  List<String> _categorias = [];
  List<Map<String, dynamic>> _categoriasList = [];
  String? _categoriaSeleccionada;
  int? _categoriaSeleccionadaId;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchCategorias();
  }

  Future<void> _fetchCategorias() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .schema('jobs')
        .from('categories')
        .select('id, name')
        .order('name');

    setState(() {
      _categoriasList = response.map((c) => {
        'id': c['id'] as int,
        'name': c['name'] as String
      }).toList();
      
      _categorias = _categoriasList.map((c) => c['name'] as String).toList();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Servicios de ubicación deshabilitados');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _errorMessage = 'Permiso de ubicación denegado');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _selectedPosition = _currentPosition; // Inicialmente la posición seleccionada es la actual
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al obtener ubicación: $e';
        _isLoading = false;
      });
    }
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
      setState(() {
        _errorMessage = 'Usuario no autenticado';
      });
      return;
    }

    if (_categoriaSeleccionadaId == null) {
      setState(() {
        _errorMessage = 'Debe seleccionar una categoría';
      });
      return;
    }

    final location = 'POINT($lon $lat)'; // Formato para columnas de tipo `geography`

    try {
      await supabase.schema('jobs').from('offers').insert({
        'user_id': user.id, // ID del usuario autenticado
        'name': _tituloController.text,
        'category_id': _categoriaSeleccionadaId,
        'amount': _montoController.text,
        'description': _descripcionController.text,
        'image_url': imageUrl,
        'location': location, // Se almacena en formato `geography`
      });

      setState(() {
        _errorMessage = 'Trabajo guardado correctamente';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar: $e';
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(labelText: 'Título del trabajo'),
            ),
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 3,
            ),
            TextField(
              controller: _montoController,
              decoration: const InputDecoration(labelText: 'Monto'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _categoriaSeleccionada,
              items: _categorias.map((categoria) => DropdownMenuItem(
                  value: categoria,
                  child: Text(categoria),
                ),).toList(),
              onChanged: (valor) {
                setState(() {
                  _categoriaSeleccionada = valor;
                  // Find the corresponding category ID
                  Map<String, dynamic>? selectedCategory;
                  for (final category in _categoriasList) {
                    if (category['name'] == valor) {
                      selectedCategory = category;
                      break;
                    }
                  }
                  _categoriaSeleccionadaId = selectedCategory?['id'] as int?;
                });
              },
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 20),
            _selectedImage != null
                ? Image.file(_selectedImage!, height: 100)
                : ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Seleccionar Imagen'),
                  ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                    : Expanded(
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _currentPosition!,
                                initialZoom: 18,
                                onTap: (tapPosition, point) {
                                  // Al tocar en el mapa, actualizar la posición seleccionada
                                  setState(() {
                                    _selectedPosition = point;
                                  });
                                },
                                onMapReady: () {
                                  // Puedes agregar acciones adicionales cuando el mapa esté listo
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedPosition ?? _currentPosition!,
                                      child: const Icon(Icons.location_pin, color: Colors.red, size: 50),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Overlay para instrucciones
                            Positioned(
                              top: 10,
                              left: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Toca en el mapa para seleccionar una ubicación diferente',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            // Botón para volver a la ubicación actual
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: FloatingActionButton(
                                onPressed: () {
                                  if (_currentPosition != null) {
                                    _mapController.move(_currentPosition!, 18);
                                    setState(() {
                                      _selectedPosition = _currentPosition;
                                    });
                                  }
                                },
                                child: const Icon(Icons.my_location),
                              ),
                            ),
                          ],
                        ),
                      ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String? imageUrl;
                if (_selectedImage != null) {
                  imageUrl = await _uploadImageToSupabase(_selectedImage!);
                }
                if (_selectedPosition != null) {
                  await _saveLocationToSupabase(
                    _selectedPosition!.latitude,
                    _selectedPosition!.longitude,
                    imageUrl,
                  );
                }
              },
              child: const Text('Guardar Trabajo'),
            ),
          ],
        ),
      ),
    );
}