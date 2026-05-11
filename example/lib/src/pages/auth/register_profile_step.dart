import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/user_service.dart';
import '../../widgets/user_profile.dart';

class RegisterProfileStep extends StatefulWidget {
  final UserProfile userProfile;
  final Function(UserProfile) onCompleted;

  const RegisterProfileStep({
    super.key,
    required this.userProfile,
    required this.onCompleted,
  });

  @override
  State<RegisterProfileStep> createState() => _RegisterProfileStepState();
}

class _RegisterProfileStepState extends State<RegisterProfileStep> {
  File? _selectedImage;
  String? _imageUrl;
  bool _imageValidated = false;
  final UserService _userService = UserService();

  // Controladores
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  String _role = 'user'; // Valor por defecto

  @override
  void initState() {
    super.initState();
    // Corregir la asignación del rol con manejo de null
    _role = widget.userProfile.role ?? 'user'; // Si es null, usar 'user' por defecto

    // Si ya hay datos en el perfil, pre-llenar los campos
    if (widget.userProfile.firstName != null) {
      _firstNameController.text = widget.userProfile.firstName!;
    }
    if (widget.userProfile.lastName != null) {
      _lastNameController.text = widget.userProfile.lastName!;
    }
    if (widget.userProfile.descripcion != null) {
      _descripcionController.text = widget.userProfile.descripcion!;
    }
    if (widget.userProfile.imageUrl != null) {
      _imageUrl = widget.userProfile.imageUrl;
      _imageValidated = true;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // Método mejorado para seleccionar imagen con múltiples opciones
  Future<void> _pickImage() async {
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

      if (imagen != null) {
        await _procesarImagenSeleccionada(imagen);
      }

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

  // Método para procesar la imagen seleccionada
  Future<void> _procesarImagenSeleccionada(XFile imagen) async {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subiendo imagen...')),
        );
      }

      // Verificar el tamaño del archivo
      final file = File(imagen.path);
      final fileSize = await file.length();

      // Si el archivo es muy grande (>2MB), comprimirlo más
      var finalImage = imagen;
      if (fileSize > 2 * 1024 * 1024) {
        finalImage = await _compressImage(imagen);
      }

      setState(() {
        _selectedImage = File(finalImage.path);
      });

      // Subir imagen sin mostrar diálogo para evitar problemas de navegación
      final uploadedUrl = await _userService.uploadProfileImage(_selectedImage!);

      if (uploadedUrl != null && mounted) {
        setState(() {
          _imageUrl = uploadedUrl;
          _imageValidated = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen subida correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al subir la imagen'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al procesar imagen: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar imagen: ${e.toString()}'),
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
      var resizedImage = originalImage;
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

  // Método alternativo más simple para dispositivos muy antiguos
  Future<void> _pickImageSimple() async {
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

  //Función que completa los datos personales del usuario
  Future<void> _completeProfile() async {
    try {
      // Validaciones iniciales
      if (_selectedImage == null || _imageUrl == null || !_imageValidated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar y subir una imagen de perfil'),
          ),
        );
        return;
      }

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final descripcion = _descripcionController.text.trim();

      // Solo validar nombre y apellido como obligatorios
      if (firstName.isEmpty || lastName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre y apellido son obligatorios')),
        );
        return;
      }

      // Mostrar mensaje de carga en lugar de diálogo
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Actualizando perfil...')),
        );
      }

      // Actualizar perfil
      widget.userProfile.firstName = firstName;
      widget.userProfile.lastName = lastName;
      widget.userProfile.imageUrl = _imageUrl;
      widget.userProfile.descripcion = descripcion; // Puede estar vacío
      widget.userProfile.role = _role;

      // Guardar en Supabase
      await _userService.updateUserProfile(widget.userProfile);

      // Notificar que se completó el perfil
      if (context.mounted) {
        widget.onCompleted(widget.userProfile);
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error completo en _completeProfile: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el perfil: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Completa tu perfil'),
      automaticallyImplyLeading: false, // No mostrar botón de retroceso
      foregroundColor: Colors.black,
    ),
    body: Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white, // Fondo blanco uniforme
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // Sección de foto de perfil
            const Text(
              'Foto de perfil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: _selectedImage != null
                  ? Column(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(75),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
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
                        onPressed: _pickImageSimple,
                        icon: const Icon(Icons.phone_android),
                        label: const Text('Modo básico'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              )
                  : Column(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 3),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Seleccionar foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            if (!_imageValidated)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '* La foto de perfil es obligatoria',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 30),
            // Sección de información personal
            const Text(
              'Información personal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Apellido',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'Cuéntanos un poco sobre ti...',
              ),
            ),
            const SizedBox(height: 30),
            // Sección de selección de rol
            const Text(
              'Selecciona tu rol',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _role = 'user';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _role == 'user'
                          ? Colors.blue
                          : Colors.grey[300],
                      foregroundColor: _role == 'user'
                          ? Colors.white
                          : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_role == 'user' ? Icons.person : Icons.person_outline, size: 30),
                        const SizedBox(height: 8),
                        const Text('Usuario'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _role = 'worker';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _role == 'worker'
                          ? Colors.blue
                          : Colors.grey[300],
                      foregroundColor: _role == 'worker'
                          ? Colors.white
                          : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_role == 'worker' ? Icons.work : Icons.work_outline, size: 30),
                        const SizedBox(height: 8),
                        const Text('Trabajador'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Botón para completar el perfil
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _completeProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'CONTINUAR',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}