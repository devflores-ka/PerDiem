import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../configuracion/change_email_screen.dart';
import '../configuracion/change_password_screen.dart';
import 'edit_name_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final VoidCallback? onProfileUpdated;

  const SettingsScreen({
    super.key,
    this.userProfile,
    this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Información personal'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Información del usuario
        if (widget.userProfile != null) ...[
          _buildUserInfoCard(),
          const SizedBox(height: 24),
        ],

        // Sección de perfil
        _buildSectionHeader('Datos personales'),
        _buildSettingsTile(
          context,
          icon: Icons.person_outline,
          title: 'Editar nombre',
          subtitle: 'Cambiar nombre y apellido',
          onTap: () => _navigateToEditName(context),
        ),
        _buildSettingsTile(
          context,
          icon: Icons.email_outlined,
          title: 'Cambiar email',
          subtitle: 'Actualizar dirección de correo',
          onTap: () => _navigateToEditEmail(context),
        ),

        const SizedBox(height: 20),

        // Sección de seguridad
        _buildSectionHeader('Seguridad'),
        _buildSettingsTile(
          context,
          icon: Icons.lock_outline,
          title: 'Cambiar contraseña',
          subtitle: 'Actualizar tu contraseña',
          onTap: () => _navigateToChangePassword(context),
        ),
        _buildSettingsTile(
          context,
          icon: Icons.security_outlined,
          title: 'Privacidad y seguridad',
          subtitle: 'Configurar permisos y privacidad',
          onTap: () => _navigateToPrivacySettings(context),
        ),

        const SizedBox(height: 20),

        // Sección de aplicación
        _buildSectionHeader('Soporte'),
        _buildSettingsTile(
          context,
          icon: Icons.help_outline,
          title: 'Ayuda y soporte',
          subtitle: 'Centro de ayuda y contacto',
          onTap: () => _navigateToHelp(context),
        ),
        _buildSettingsTile(
          context,
          icon: Icons.info_outline,
          title: 'Acerca de',
          subtitle: 'Versión e información de la app',
          onTap: () => _showAboutDialog(context),
        ),

        const SizedBox(height: 20),
      ],
    ),
  );

  // En SettingsScreen, reemplazar _buildUserInfoCard() con:
  Widget _buildUserInfoCard() => StreamBuilder<User?>(
    stream: supabase.auth.onAuthStateChange.map((data) => data.session?.user),
    builder: (context, snapshot) {
      final user = snapshot.data ?? supabase.auth.currentUser;
      final displayEmail = user?.email ?? widget.userProfile?['email'] ?? '';

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade200,
              backgroundImage: widget.userProfile?['imageUrl'] != null
                  ? NetworkImage(widget.userProfile!['imageUrl'])
                  : null,
              child: widget.userProfile?['imageUrl'] == null
                  ? Icon(
                Icons.person,
                size: 30,
                color: Colors.blue.shade700,
              )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.userProfile?['firstName'] ?? ''} ${widget.userProfile?['lastName'] ?? ''}'.trim(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (displayEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        displayEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4, right: 4),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
      ),
    ),
  );

  Widget _buildSettingsTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
        Color? iconColor,
      }) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.blue.shade700,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    ),
  );

  // Métodos de navegación para funciones específicas
  void _navigateToEditEmail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeEmailScreen(
          userProfile: widget.userProfile, // ✅ Pasar el perfil
          onProfileUpdated: widget.onProfileUpdated, // ✅ Pasar callback
        ),
      ),
    );
  }

// También corregir los otros métodos para consistencia
  void _navigateToEditName(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditNameScreen(
          userProfile: widget.userProfile,
          onProfileUpdated: widget.onProfileUpdated,
        ),
      ),
    );
  }

  void _navigateToChangePassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePasswordScreen(
          userProfile: widget.userProfile,
          onProfileUpdated: widget.onProfileUpdated,
        ),
      ),
    );
  }

  void _navigateToPrivacySettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función en desarrollo'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToHelp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función en desarrollo'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de la app
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.work,
                size: 48,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // Nombre de la app
            const Text(
              'Mi App de Trabajos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Descripción
            Text(
              'Aplicación para conectar profesionales y clientes de manera fácil y segura.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Versión
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Versión 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón cerrar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}