import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final VoidCallback? onProfileUpdated;

  const ChangePasswordScreen({
    super.key,
    this.userProfile,
    this.onProfileUpdated,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Criterios de validación
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cambiar contraseña'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del proceso nativo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Cambio de contraseña',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Ingresa tu nueva contraseña'),
                  const Text('2. Supabase actualizará tu contraseña automáticamente'),
                  const Text('3. No necesitas ingresar tu contraseña actual'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Información de seguridad
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Seguridad de contraseña',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu nueva contraseña debe cumplir con los siguientes requisitos de seguridad:',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Contraseña actual
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrentPassword,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _isLoading ? Colors.grey.shade100 : null,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu contraseña actual';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Nueva contraseña
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _isLoading ? Colors.grey.shade100 : null,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa una nueva contraseña';
                }
                if (!_isPasswordValid) {
                  return 'La contraseña no cumple con los requisitos de seguridad';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Criterios de validación
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
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

            const SizedBox(height: 20),

            // Confirmar contraseña
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _isLoading ? Colors.grey.shade100 : null,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma tu nueva contraseña';
                }
                if (value != _newPasswordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Consejos de seguridad
            Container(
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
                      Icon(Icons.tips_and_updates, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Consejos de seguridad',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• No uses información personal obvia'),
                  const Text('• Evita patrones de teclado simples'),
                  const Text('• No reutilices contraseñas de otras cuentas'),
                  const Text('• Considera usar un gestor de contraseñas'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Botón de cambio
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.lock_reset),
                label: Text(_isLoading ? 'Cambiando contraseña...' : 'Cambiar contraseña'),
              ),
            ),

            const SizedBox(height: 16),

            // Cancelar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

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
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;
      final email = supabase.auth.currentUser?.email;

      if (email == null) {
        throw Exception('Usuario no autenticado');
      }

      // Paso 1: Reautenticar con contraseña actual
      await supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      // Paso 2: Cambiar contraseña
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        // Mostrar diálogo de éxito
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('¡Contraseña actualizada!'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu contraseña ha sido cambiada exitosamente.'),
                SizedBox(height: 12),
                Text('La nueva contraseña será efectiva inmediatamente.'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Volver a settings
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error al cambiar contraseña';

        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('invalid login credentials') ||
            errorStr.contains('incorrect password')) {
          errorMessage = 'La contraseña actual es incorrecta';
        } else if (errorStr.contains('password should be at least')) {
          errorMessage = 'La contraseña debe tener al menos 6 caracteres';
        } else if (errorStr.contains('weak password')) {
          errorMessage = 'La contraseña es muy débil. Usa una más segura';
        } else if (errorStr.contains('same password')) {
          errorMessage = 'La nueva contraseña debe ser diferente a la actual';
        } else if (errorStr.contains('user not found')) {
          errorMessage = 'Usuario no encontrado. Inicia sesión nuevamente';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}