import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangeEmailScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final VoidCallback? onProfileUpdated;

  const ChangeEmailScreen({
    super.key,
    this.userProfile,
    this.onProfileUpdated,
  });

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();

  bool _isLoading = false;
  String _currentEmail = '';

  @override
  void initState() {
    super.initState();
    _currentEmail = widget.userProfile?['email'] ?? supabase.auth.currentUser?.email ?? '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cambiar email'),
      foregroundColor: Colors.black,
      elevation: 2,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email actual
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
                  const Text(
                    'Email actual',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentEmail,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                        'Proceso de cambio',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Ingresa tu nuevo email'),
                  const Text('2. Se enviará un enlace de confirmación al NUEVO email'),
                  const Text('3. Haz click en el enlace para confirmar el cambio'),
                  const Text('4. Tu email se actualizará automáticamente'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Nuevo email
            TextFormField(
              controller: _newEmailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Nuevo email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _isLoading ? Colors.grey.shade100 : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El email es requerido';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                  return 'Ingresa un email válido';
                }
                if (value.trim().toLowerCase() == _currentEmail.toLowerCase()) {
                  return 'El nuevo email debe ser diferente al actual';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Botón de cambio
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _changeEmail,
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
                    : const Icon(Icons.send),
                label: Text(_isLoading ? 'Enviando...' : 'Solicitar cambio de email'),
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

            const SizedBox(height: 24),

            // Nota importante
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
                      Icon(Icons.warning_amber, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Importante',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• El enlace de confirmación se enviará al NUEVO email'),
                  const Text('• Tu email actual seguirá activo hasta confirmar el cambio'),
                  const Text('• Revisa spam si no recibes el email'),
                  const Text('• El enlace expira en 24 horas'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newEmail = _newEmailController.text.trim();

      // Solicitar cambio de email usando Supabase nativo
      await supabase.auth.updateUser(
        UserAttributes(email: newEmail),
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
                Icon(Icons.mark_email_read, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('Email de confirmación enviado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Se ha enviado un enlace de confirmación a:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    newEmail,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Haz click en el enlace para completar el cambio de email.'),
                const SizedBox(height: 8),
                Text(
                  'Revisa spam si no lo encuentras.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context, true); // Volver a settings indicando que hubo cambio
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
        String errorMessage = 'Error al solicitar cambio';

        // Manejar errores específicos
        if (e.toString().contains('Email rate limit exceeded')) {
          errorMessage = 'Has alcanzado el límite de cambios de email. Intenta más tarde.';
        } else if (e.toString().contains('same email')) {
          errorMessage = 'El nuevo email debe ser diferente al actual.';
        } else if (e.toString().contains('invalid email')) {
          errorMessage = 'El formato del email no es válido.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
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
    _newEmailController.dispose();
    super.dispose();
  }
}