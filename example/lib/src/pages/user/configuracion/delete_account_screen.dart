import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth.dart';
import '/l10n/generated/app_localizations.dart';

class DeleteAccountScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const DeleteAccountScreen({
    super.key,
    this.userProfile,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final supabase = Supabase.instance.client;
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() {
      // Solo forzamos la reconstrucción. La validación se hará en el build.
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Validamos dinámicamente usando la palabra clave traducida
    final bool canDelete = _confirmController.text.trim().toUpperCase() == l10n.deleteKeyword.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deleteAccountTitle),
        foregroundColor: Colors.red,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono de advertencia principal
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 64,
                  color: Colors.red.shade600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              l10n.irreversibleAction,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Consecuencias de eliminar la cuenta
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWarningItem(l10n.cantAccessAccount),
                  const SizedBox(height: 8),
                  _buildWarningItem(l10n.profileNotVisible),
                  const SizedBox(height: 8),
                  _buildWarningItem(l10n.cantRegisterAgain),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              l10n.confirmDeleteInstruction,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _confirmController,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: l10n.deleteKeyword,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _isLoading ? Colors.grey.shade100 : null,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botón de Eliminación (Pausa)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (canDelete && !_isLoading) ? () => _softDeleteAccount(l10n) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.red.shade200,
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
                    : const Icon(Icons.delete_forever),
                label: Text(_isLoading ? l10n.processing : l10n.deactivateMyAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, size: 8, color: Colors.red.shade700).padOnly(top: 6, right: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.red.shade900, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _softDeleteAccount(AppLocalizations l10n) async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId != null) {
        // 1. Ocultar la cuenta en tu base de datos (Soft Delete)
        // Ensure boolean 'false' is used, not the string 'FALSE'
        await supabase.schema('chats').from('users').update({
          'is_active': false,
          'deletedAt': DateTime.now().toIso8601String(),
        }).eq('id', userId);

        // 2. Cerrar sesión
        await supabase.auth.signOut();

        if (mounted) {
          // 3. Navegar a la pantalla de inicio / login y limpiar el historial
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()), // Cambia LoginScreen por el nombre real de tu widget
                (route) => false,
          );
        }
      }
    } catch (e) {
      // Print the error to the console so it doesn't fail silently!
      debugPrint('Error deactivating account: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeactivatingAccount),
            backgroundColor: Colors.red.shade700,
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
    _confirmController.dispose();
    super.dispose();
  }
}

// Extensión para simplificar el padding en _buildWarningItem
extension PaddingExtension on Widget {
  Widget padOnly({double top = 0, double right = 0, double bottom = 0, double left = 0}) => Padding(
      padding: EdgeInsets.only(top: top, right: right, bottom: bottom, left: left),
      child: this,
    );
}