// user_profile_widget.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/l10n/generated/app_localizations.dart';

import '../pages/user/personal/update_categories_screen.dart';
import '../services/user_service.dart';

class UserProfileWidget extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final VoidCallback? onProfileUpdated;

  const UserProfileWidget({
    super.key,
    required this.userProfile,
    this.onProfileUpdated,
  });

  @override
  State<UserProfileWidget> createState() => _UserProfileWidgetState();
}

class _UserProfileWidgetState extends State<UserProfileWidget> {
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _userCategories = [];
  Map<int, List<Map<String, dynamic>>> _userOficios = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCategoriesAndOficios();
  }

  Future<void> _loadUserCategoriesAndOficios() async {
    try {
      final categoriesAndOficios = await _userService.getUserCategoriesWithOficios();
      setState(() {
        _userCategories = categoriesAndOficios['categories'] ?? [];
        _userOficios = categoriesAndOficios['oficios'] ?? {};
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading categories and oficios: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToUpdateCategories() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UpdateCategoriesScreen(),
      ),
    );

    if (result == true) {
      // Recargar datos si hubo cambios
      await _loadUserCategoriesAndOficios();
      if (widget.onProfileUpdated != null) {
        widget.onProfileUpdated!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Información básica del usuario
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Avatar y nombre
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue.shade200,
                backgroundImage: widget.userProfile['photo_url'] != null
                    ? NetworkImage(widget.userProfile['photo_url'])
                    : null,
                child: widget.userProfile['photo_url'] == null
                    ? Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.blue.shade700,
                )
                    : null,
              ),
              const SizedBox(height: 16),

              // Nombre del usuario
              Text(
                widget.userProfile['full_name'] ?? 'Sin nombre',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              // Email
              if (widget.userProfile['email'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.userProfile['email'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Sección de Categorías y Oficios
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con título y botón de editar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.mySpeciality,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _navigateToUpdateCategories,
                    icon: const Icon(Icons.edit),
                    tooltip: l10n.editCatdnOf,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_userCategories.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noCatConf,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.addCats,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _navigateToUpdateCategories,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addSpecs),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
              // Mostrar categorías y oficios
                Column(
                  children: _userCategories.map((category) {
                    final categoryId = category['id'] as int;
                    final oficios = _userOficios[categoryId] ?? [];

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre de la categoría
                          Row(
                            children: [
                              Icon(
                                Icons.category,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category['name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (oficios.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            // Oficios de la categoría
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: oficios.map((oficio) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Text(
                                  oficio['name'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),).toList(),
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                l10n.noProff,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}