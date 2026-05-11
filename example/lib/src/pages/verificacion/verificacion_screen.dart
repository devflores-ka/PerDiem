import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'custom_camera_screen.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final supabase = Supabase.instance.client;
  
  File? _frontImage;
  File? _backImage;
  bool _isUploading = false;
  String? _validatedRut;
  String? _validatedName;

  final ImagePicker _picker = ImagePicker();

  // Tomar foto a carnet de identidad con la cámara
  Future<void> _pickImage(bool isFront) async {
    try {
      // Navegación a CustomCameraScreen
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomCameraScreen(
              isFront: isFront,
              onCaptureAndValidate: (XFile file, String? validatedRut, String? validatedName) {
                setState(() {
                  if (isFront) {
                    _frontImage = File(file.path);
                    _validatedRut = validatedRut; // Guardar RUT para uso futuro
                    _validatedName = validatedName; // Guardar nombre para uso futuro
                  } else {
                    _backImage = File(file.path);
                  }
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando imagen: $e')),
      );
    }
  }

  // Subir imágenes y actualizar perfil
  Future<void> _submitVerification() async {
    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes subir ambas fotos del carnet.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No usuario logueado');

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 1. Subir Frente
      final frontPath = '${user.id}/front_$timestamp.jpg';
      await supabase.storage.from('verification_docs').upload(
        frontPath,
        _frontImage!,
        fileOptions: const FileOptions(upsert: true),
      );
      // ELIMINADO: getPublicUrl

      // 2. Subir Dorso
      final backPath = '${user.id}/back_$timestamp.jpg';
      await supabase.storage.from('verification_docs').upload(
        backPath,
        _backImage!,
        fileOptions: const FileOptions(upsert: true),
      );
      // ELIMINADO: getPublicUrl

      // 3. Actualizar Base de Datos (GUARDAMOS LOS PATHS, NO URLs)
      await supabase.schema('chats').from('users').update({
        'verification_status': 'pending',
        'verification_docs': {
          'front_path': frontPath, // Guardamos la ruta interna
          'back_path': backPath,   // Guardamos la ruta interna
          'uploaded_at': DateTime.now().toIso8601String(),
        }
      }).eq('id', user.id);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('¡Solicitud Enviada!'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 50),
                SizedBox(height: 16),
                Text('Hemos recibido tus documentos. Revisaremos tu identidad lo antes posible.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir documentos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Identidad'),
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Para mantener la seguridad de la comunidad, necesitamos verificar tu Carnet de Identidad.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // CARD FRENTE
            _buildUploadCard(
              title: 'Carnet (Frente)',
              image: _frontImage,
              onTap: () => _pickImage(true),
            ),

            const SizedBox(height: 20),

            // CARD DORSO
            _buildUploadCard(
              title: 'Carnet (Dorso)',
              image: _backImage,
              onTap: () => _pickImage(false),
            ),

            const SizedBox(height: 40),

            // BOTÓN ENVIAR
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                ),
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ENVIAR SOLICITUD', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

  Widget _buildUploadCard({required String title, File? image, required VoidCallback onTap}) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('Toca para subir', style: TextStyle(fontSize: 12, color: Colors.blue)),
                ],
              ),
      ),
    );
}