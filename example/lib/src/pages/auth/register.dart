import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  File? _selectedImage;
  String? _imageUrl;
  bool _imageValidated = false;
  bool _showProfileForm = false;

  // Variables para campos adicionales
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  String _role = 'user'; // Valor por defecto

  // Controladores para el formulario de registro
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Función para registrar el usuario básico
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
        const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Registrar el usuario en Supabase
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      if (response.user != null) {
        // Registro exitoso, ahora mostrar el formulario de perfil
        setState(() {
          _showProfileForm = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear la cuenta')),
        );
      }
    } catch (e) {
      // Cerrar diálogo de carga si hay excepción
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error durante el registro: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
          source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });

        // Mostrar indicador de carga durante la subida
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) =>
          const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Subir imagen
        final uploadedUrl = await _uploadImageToSupabase(_selectedImage);

        // Cerrar diálogo de carga
        Navigator.of(context).pop();

        if (uploadedUrl != null) {
          setState(() {
            _imageUrl = uploadedUrl;
            _imageValidated = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Imagen subida correctamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la imagen')),
          );
        }
      }
    } catch (e) {
      // Cerrar diálogo de carga si hay excepción
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Error al seleccionar/subir imagen: ${e.toString()}')),
      );
    }
  }

  Future<String?> _uploadImageToSupabase(File? imageFile) async {
    if (imageFile == null) return null;

    try {
      // Modificado para incluir el prefijo 'register/' según la política establecida
      final fileName = 'register/profile_${DateTime
          .now()
          .millisecondsSinceEpoch}.png';
      final bytes = await imageFile.readAsBytes();

      final supabaseClient = Supabase.instance.client;

      // Subir la imagen
      final response = await supabaseClient.storage.from('profile_images')
          .uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      if (kDebugMode) {
        print('Upload response: $response');
      }

      // Obtener la URL pública
      final publicUrl = supabaseClient.storage.from('profile_images')
          .getPublicUrl(fileName);

      if (kDebugMode) {
        print('Image URL: $publicUrl');
      }

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Upload error: $e');
      }
      return null;
    }
  }

  Future<void> _completeProfile() async {
    try {
      // Validaciones iniciales
      if (_selectedImage == null || _imageUrl == null || !_imageValidated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Debes seleccionar y subir una imagen de perfil')),
        );
        return;
      }

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final descripcion = _descripcionController.text.trim();

      if (firstName.isEmpty || lastName.isEmpty || descripcion.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa todos los campos requeridos')),
        );
        return;
      }

      // Mostrar indicador de carga SIN await
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
        const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (kDebugMode) {
        print('Verificando usuario: ${user?.id}');
        print('Email verificado: ${user?.emailConfirmedAt}');
        print('Usuario metadata: ${user?.userMetadata}');
      }

      if (user == null) {
        Navigator.of(context).pop(); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró una sesión activa')),
        );
        return;
      }

      // Actualizar metadatos del usuario en auth
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'first_name': firstName,
            'last_name': lastName,
            'image_url': _imageUrl ?? '',
            'descripcion': descripcion,
            'role': _role,
          },
        ),
      );

      if (kDebugMode) {
        print('Metadatos de usuario actualizados');
      }

      // Actualizar también en SupabaseChatCore
      await SupabaseChatCore.instance.updateUser(
        types.User(
          id: user.id,
          firstName: firstName,
          lastName: lastName,
          imageUrl: _imageUrl,
        ),
      );

      if (kDebugMode) {
        print('SupabaseChatCore actualizado');
      }

      // Crear los datos para inserción
      final now = DateTime
          .now()
          .millisecondsSinceEpoch;
      final userData = {
        'id': user.id,
        'firstName': firstName,
        'lastName': lastName,
        'imageUrl': _imageUrl,
        'descripcion': descripcion,
        'role': _role,
        'createdAt': now,
        'updatedAt': now,
        'lastSeen': now,
      };

      if (kDebugMode) {
        print('Intentando insertar con datos: $userData');
      }

      try {
        // Intento 1: Insertar directamente en la tabla
        try {
          final response = await supabase
              .from('chats.users') // Ruta explícita al esquema.tabla
              .insert(userData)
              .select();

          if (kDebugMode) {
            print('Inserción exitosa: $response');
          }
        } catch (e1) {
          if (kDebugMode) {
            print('Error inserción en chats.users: $e1');
          }

          // Intento 2: Usar RPC correctamente
          try {
            if (kDebugMode) {
              print('Intentando con RPC...');
            }

            // CORREGIDO: Pasar los parámetros como JSON con nombres según la función
            final response = await supabase.rpc(
              'insert_into_chats_users',
              params: {
                'id': user.id,
                'firstName': firstName,
                'lastName': lastName,
                'imageUrl': _imageUrl,
                'descripcion': descripcion,
                'role': _role,
                'createdAt': now,
                'updatedAt': now,
                'lastSeen': now,
              },
            );

            if (kDebugMode) {
              print('Inserción mediante RPC exitosa: $response');
            }
          } catch (rpcError) {
            if (kDebugMode) {
              print('Error en RPC: $rpcError');
            }

            // Intento 3: Insertar directamente en 'users' (por si acaso)
            try {
              if (kDebugMode) {
                print('Intentando insertar en tabla users...');
              }

              final response = await supabase
                  .from('users')
                  .insert(userData)
                  .select();

              if (kDebugMode) {
                print('Inserción en users exitosa: $response');
              }
            } catch (e3) {
              if (kDebugMode) {
                print('Error en inserción a users: $e3');
              }
              throw 'No se pudo guardar el perfil después de múltiples intentos';
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error general de inserción: $e');
        }
        throw e;
      }

      // Cerrar diálogo y navegar a la página de inicio
      Navigator.of(context).pop(); // Cerrar loading

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } catch (e) {
      // Asegurarse de cerrar el diálogo en caso de error
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (kDebugMode) {
        print('Error completo en _completeProfile: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al actualizar el perfil: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _descripcionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showProfileForm) {
      // Pantalla de perfil modificada con fondo blanco uniforme
      return Scaffold(
        appBar: AppBar(
          title: const Text('Completa tu perfil'),
          automaticallyImplyLeading: false, // No mostrar botón de retroceso
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
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
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Cambiar foto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20,
                              vertical: 12),
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
                            Icon(_role == 'user' ? Icons.person : Icons
                                .person_outline, size: 30),
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
                            Icon(_role == 'worker' ? Icons.work : Icons
                                .work_outline, size: 30),
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
                      'COMPLETAR PERFIL',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    } else {
      // Pantalla de registro con fondo blanco uniforme
      return Scaffold(
        appBar: AppBar(
          title: const Text('Registro'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white, // Fondo blanco uniforme
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/flyer_logo.png',
                    height: 100,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'REGISTRO',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Formulario sin Card
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Campo de correo
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu correo';
                            }
                            // Validación básica de email
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Ingresa un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Campo de contraseña
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa una contraseña';
                            }
                            if (value.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Campo para confirmar contraseña
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor confirma tu contraseña';
                            }
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        // Botón de registro
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'REGISTRARSE',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Enlace para iniciar sesión
                        TextButton(
                          onPressed: () {
                            // Aquí puedes navegar a la pantalla de inicio de sesión
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            '¿Ya tienes una cuenta? Inicia sesión',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}