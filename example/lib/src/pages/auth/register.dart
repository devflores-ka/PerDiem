import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../services/user_service.dart';
import '../../widgets/user_profile.dart';
import 'auth.dart';
import 'legal_doc_screen.dart';
import 'register_categories_skills_step.dart';
import 'register_personal_data_step.dart';
import 'register_profile_step.dart';
import 'terms_screen.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores de flujo
  bool _showProfileForm = false;
  bool _showPersonalDataForm = false;
  bool _showCategoriesSkillsForm = false;
  bool _acceptedTerms = false;

  // Datos de usuario que se van recopilando
  final UserProfile _userProfile = UserProfile();

  // Controladores para el formulario de registro
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Variables para controlar visibilidad de contraseñas
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Variables para validación de contraseña
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  // Servicio de usuario para operaciones con Supabase
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = _passwordController.text;
    if (mounted) { // ✅ Verificar que esté montado
      setState(() {
        _hasMinLength = password.length >= 8;
        _hasUppercase = password.contains(RegExp(r'[A-Z]'));
        _hasLowercase = password.contains(RegExp(r'[a-z]'));
        _hasNumber = password.contains(RegExp(r'[0-9]'));
        _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      });
    }
  }

  bool get _isPasswordValid =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;

  Widget _buildCriteriaRow(String text, bool isValid) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isValid ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    ),
  );

  // Función para registrar el usuario básico (primer paso)
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Debes aceptar los Términos y Condiciones para continuar'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (kDebugMode) {
        print('DEBUG: Intentando registrar: $email');
      }

      // Guardar datos en el objeto UserProfile
      _userProfile.email = email;

      // Mostrar indicador de carga
      // NUNCA hacer caso y colocar la await, se queda dando vueltas
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
        );
      }

      if (kDebugMode) {
        print('DEBUG: Llamando a registerUser en UserService');
      }

      // Registrar el usuario en Supabase
      final response = await _userService.registerUser(email, password);

      if (kDebugMode) {
        print("DEBUG: Respuesta recibida: ${response.user != null ? 'Usuario creado' : 'Respuesta vacía'}");
      }

      // Cerrar diálogo de carga
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (response.user != null) {
        if (kDebugMode) {
          print('DEBUG: Registro exitoso, usuario ID: ${response.user!.id}');
        }

        if (mounted) { // ✅ Verificar que esté montado
          setState(() {
            _showProfileForm = true;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al crear la cuenta: respuesta vacía')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Error durante el registro: $e');
      }

      // Cerrar diálogo de carga si hay excepción
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error durante el registro: ${e.toString()}')),
        );
      }
    }
  }

  // Método para avanzar al tercer paso (datos personales)
  void _onProfileCompleted(UserProfile profile) {
    if (mounted) { // ✅ Verificar que esté montado
      setState(() {
        _userProfile.firstName = profile.firstName;
        _userProfile.lastName = profile.lastName;
        _userProfile.imageUrl = profile.imageUrl;
        _userProfile.descripcion = profile.descripcion;
        _userProfile.role = profile.role;

        _showProfileForm = false;
        _showPersonalDataForm = true;
      });
    }
  }

  // Método para avanzar al cuarto paso (categorías y habilidades)
  void _onPersonalDataCompleted() {
    if (mounted) {
      setState(() {
        _showPersonalDataForm = false;

        // Verificar el rol del usuario
        if (_userProfile.role == 'worker') {
          // Si es trabajador, continuar al paso de categorías y habilidades
          _showCategoriesSkillsForm = true;
        } else {
          // Si es usuario regular, finalizar el registro directamente
          _onUserRegistrationCompleted();
        }
      });
    }
  }

  // Método para finalizar el registro - VERSIÓN SÚPER SIMPLIFICADA
  Future<void> _onRegistrationCompleted() async {
    if (kDebugMode) {
      print('🎯 _onRegistrationCompleted() INICIADO');
    }

    if (!mounted) {
      if (kDebugMode) {
        print('❌ Widget no montado, abortando');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('⏳ Esperando 1 segundo para asegurar sesión...');
      }

      // Aumentar el tiempo de espera
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) {
        if (kDebugMode) {
          print('❌ Widget se desmontó durante la espera');
        }
        return;
      }

      if (kDebugMode) {
        print('🏠 Iniciando navegación a MainScreen...');
      }

      // Navegación con verificación adicional
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );

        if (kDebugMode) {
          print('✅ Navegación iniciada exitosamente');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en _onRegistrationCompleted: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de navegación: $e')),
        );

        // Fallback: navegar a AuthScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  // Método para finalizar registro de usuario regular (sin categorías/habilidades)
  Future<void> _onUserRegistrationCompleted() async {
    if (kDebugMode) {
      print('🎯 _onUserRegistrationCompleted() INICIADO');
    }

    if (!mounted) {
      if (kDebugMode) {
        print('❌ Widget no montado, abortando');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('💾 Actualizando perfil final de usuario...');
      }

      // Solo actualizar el perfil básico sin categorías ni habilidades
      await _userService.updateUserProfile(_userProfile);

      if (kDebugMode) {
        print('⏳ Esperando 1 segundo para asegurar sesión...');
      }

      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) {
        if (kDebugMode) {
          print('❌ Widget se desmontó durante la espera');
        }
        return;
      }

      if (kDebugMode) {
        print('🏠 Iniciando navegación a MainScreen...');
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );

        if (kDebugMode) {
          print('✅ Navegación iniciada exitosamente');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en _onUserRegistrationCompleted: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de navegación: $e')),
        );

        // Fallback: navegar a AuthScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCategoriesSkillsForm) {
      // CUARTO PASO: Solo para trabajadores
      return RegisterCategoriesSkillsStep(
        userProfile: _userProfile,
        onCompleted: _onRegistrationCompleted, // Para trabajadores
      );
    } else if (_showPersonalDataForm) {
      // TERCER PASO: Datos personales (para ambos roles)
      return RegisterPersonalDataStep(
        userProfile: _userProfile,
        onCompleted: _onPersonalDataCompleted, // Este método maneja el flujo según el rol
      );
    } else if (_showProfileForm) {
      // SEGUNDO PASO: Formulario de perfil (para ambos roles)
      return RegisterProfileStep(
        userProfile: _userProfile,
        onCompleted: _onProfileCompleted,
      );
    } else {
      // PRIMER PASO: Formulario de registro inicial
      return Scaffold(
        appBar: AppBar(
          title: const Text('Registro'),
          foregroundColor: Colors.black,
        ),
        body: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo.png',
                    height: 250,
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
                        // Campo de contraseña con toggle de visibilidad
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                if (mounted) { // ✅ Verificar que esté montado
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                }
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa una contraseña';
                            }
                            if (!_isPasswordValid) {
                              return 'La contraseña no cumple con los requisitos de seguridad';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Criterios de validación de contraseña
                        if (_passwordController.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Requisitos de contraseña:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildCriteriaRow('Al menos 8 caracteres', _hasMinLength),
                                _buildCriteriaRow('Una letra mayúscula', _hasUppercase),
                                _buildCriteriaRow('Una letra minúscula', _hasLowercase),
                                _buildCriteriaRow('Un número', _hasNumber),
                                _buildCriteriaRow('Un carácter especial', _hasSpecialChar),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),
                        // Campo para confirmar contraseña con toggle de visibilidad
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                if (mounted) { // Verificar que esté montado
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                }
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: _obscureConfirmPassword,
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
                        // CHECKBOX DE TÉRMINOS Y CONDICIONES
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // Alinear arriba si el texto es largo
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _acceptedTerms,
                                activeColor: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (bool? value) {
                                  setState(() {
                                    _acceptedTerms = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Navegar a la pantalla de términos
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LegalDocScreen(docType: 'terms'),
                                    ),
                                  );
                                },
                                child: RichText(
                                  text: const TextSpan(
                                    text: 'He leído y acepto los ',
                                    style: TextStyle(color: Colors.black87, fontSize: 14),
                                    children: [
                                      TextSpan(
                                        text: 'Términos y Condiciones de Uso',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' y la ',
                                        style: TextStyle(color: Colors.black87),
                                      ),
                                      TextSpan(
                                        text: 'Política de Privacidad',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                        // Nota: Aquí podrías añadir otro recognizer para abrir la política por separado si quisieras
                                      ),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                                fontSize: 16, fontWeight: FontWeight.bold,),
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