import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';
import '../../../managers/language_provider.dart';
import '../../auth/legal_doc_screen.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
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
  Widget build(BuildContext context) {
    // Obtenemos las traducciones (puede ser null, por eso usamos !)
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        foregroundColor: Colors.black,
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

          // ✅ SELECTOR DE IDIOMA (Corregido)
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blue),
            title: Text(l10n.language), // "Idioma" desde el archivo arb
            trailing: DropdownButton<String>(
              // Escuchamos el idioma actual del Provider
              value: context.watch<LanguageProvider>().locale.languageCode,
              icon: const Icon(Icons.arrow_drop_down),
              underline: const SizedBox(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  // Cambiamos el idioma usando el Provider
                  context.read<LanguageProvider>().changeLanguage(Locale(newValue));
                }
              },
              items: const [
                DropdownMenuItem(value: 'es', child: Text('Español 🇪🇸')),
                DropdownMenuItem(value: 'en', child: Text('English 🇺🇸')),
              ],
            ),
          ),

          const Divider(),

          // Sección de perfil
          _buildSectionHeader(l10n.settings), // "Ajustes"
          _buildSettingsTile(
            context,
            icon: Icons.person_outline,
            title: l10n.editName,
            subtitle: l10n.editNameSubtitle,
            onTap: () => _navigateToEditName(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.email_outlined,
            title: l10n.changeEmail,
            subtitle: l10n.changeEmailSubtitle,
            onTap: () => _navigateToEditEmail(context),
          ),

          const SizedBox(height: 20),

          // Sección de seguridad
          _buildSectionHeader(l10n.securityTitle),
          _buildSettingsTile(
            context,
            icon: Icons.lock_outline,
            title: l10n.changePassword,
            subtitle: l10n.changePasswordSubtitle,
            onTap: () => _navigateToChangePassword(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.security_outlined,
            title: l10n.privacySecurity,
            subtitle: l10n.privacyPolicySubtitle,
            onTap: () => _navigateToPrivacySettings(context),
          ),

          const SizedBox(height: 20),

          // SECCIÓN LEGAL
          _buildSectionHeader(l10n.legalTitle),
          _buildSettingsTile(
            context,
            icon: Icons.description_outlined,
            title: l10n.terms, // "Términos y Condiciones"
            subtitle: l10n.termsSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalDocScreen(docType: 'terms'),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: l10n.privacy, // "Política de Privacidad"
            subtitle: l10n.privacyPolicySubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalDocScreen(docType: 'privacy'),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Sección de aplicación
          _buildSectionHeader(l10n.appTitle),
          _buildSettingsTile(
            context,
            icon: Icons.help_outline,
            title: l10n.helpSupport,
            subtitle: l10n.helpSupportSubtitle,
            onTap: () => _navigateToHelp(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline,
            title: l10n.about,
            subtitle: l10n.aboutSubtitle,
            onTap: () => _showAboutDialog(context),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

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
  }) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0, // Plano para diseño más limpio
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)),
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

  // --- MÉTODOS DE NAVEGACIÓN ---

  void _navigateToEditEmail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeEmailScreen(
          userProfile: widget.userProfile,
          onProfileUpdated: widget.onProfileUpdated,
        ),
      ),
    );
  }

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
            const Text(
              'PerDiem App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Conectando profesionales y clientes.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}