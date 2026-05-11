import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../widgets/user_profile.dart';

class RegisterCategoriesSkillsStep extends StatefulWidget {
  final UserProfile userProfile;
  final Future<void> Function() onCompleted;

  const RegisterCategoriesSkillsStep({
    super.key,
    required this.userProfile,
    required this.onCompleted,
  });

  @override
  State<RegisterCategoriesSkillsStep> createState() => _RegisterCategoriesSkillsStepState();
}

class _RegisterCategoriesSkillsStepState extends State<RegisterCategoriesSkillsStep> {
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _allCategories = []; // Lista de todas las categorías
  bool _isLoadingCategories = false; // Estado de carga

  // Variables para categorías y oficios
  final List<Map<String, dynamic>> _selectedCategories = [];
  List<Map<String, dynamic>> _searchResults = []; // Resultados de búsqueda en tiempo real

  // Mapa para almacenar oficios por categoría
  final Map<int, List<Map<String, dynamic>>> _oficiosPorCategoria = {};
  final Map<int, List<Map<String, dynamic>>> _selectedOficiosPorCategoria = {};

  // Variables para habilidades
  final List<Map<String, dynamic>> _userSkills = [];

  // Controladores para búsqueda
  final TextEditingController _searchCategoryController = TextEditingController();
  final TextEditingController _searchSkillController = TextEditingController();

  bool _isLoadingOficios = false;
  bool _isSearchingCategories = false; // Nueva variable para estado de búsqueda

  @override
  void initState() {
    super.initState();
    _loadAllCategories(); // Cargar todas las categorías al iniciar
  }

  @override
  void dispose() {
    _searchCategoryController.dispose();
    _searchSkillController.dispose();
    super.dispose();
  }

  // Método para cargar todas las categorías disponibles
  Future<void> _loadAllCategories() async {
    setState(() => _isLoadingCategories = true);

    try {
      final categories = await _userService.getAllCategories(); // Necesitarás este método en tu servicio
      setState(() {
        _allCategories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar categorías: $e');
      }
      setState(() => _isLoadingCategories = false);
    }
  }

  // 1. Método para mostrar el modal de categorías (adaptado del map_screen)
  void _showCategorySelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Text(
              'Selecciona categorías',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            // Mensaje informativo
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Máximo 2 categorías - ${_selectedCategories.length}/2 seleccionadas',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de todas las categorías (SIN barra de búsqueda)
            Expanded(
              child: _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : _allCategories.isEmpty
                  ? const Center(
                child: Text(
                  'No hay categorías disponibles',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _allCategories.length,
                itemBuilder: (context, index) {
                  final category = _allCategories[index];
                  final isAlreadySelected = _selectedCategories
                      .any((c) => c['id'] == category['id']);
                  final canSelect = _selectedCategories.length < 2;

                  return ListTile(
                    leading: Icon(
                      _getCategoryIcon(category['name']),
                      color: isAlreadySelected
                          ? Colors.green
                          : canSelect
                          ? Colors.blueAccent
                          : Colors.grey,
                    ),
                    title: Text(category['name']),
                    subtitle: category['description'] != null
                        ? Text(
                      category['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    )
                        : null,
                    trailing: isAlreadySelected
                        ? const Icon(Icons.check, color: Colors.green)
                        : canSelect
                        ? const Icon(Icons.add, color: Colors.blueAccent)
                        : const Icon(Icons.block, color: Colors.grey),
                    onTap: isAlreadySelected || !canSelect
                        ? null
                        : () {
                      _addCategory(category);
                      // NO cerrar el modal aquí para permitir seleccionar múltiples categorías
                      setState(() {}); // Solo actualizar el estado
                    },
                    enabled: !isAlreadySelected && canSelect,
                    // Destacar las categorías seleccionadas
                    tileColor: isAlreadySelected
                        ? Colors.green.shade50
                        : null,
                  );
                },
              ),
            ),

            // Botón para cerrar el modal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    _selectedCategories.isEmpty
                        ? 'Cerrar'
                        : 'Continuar con ${_selectedCategories.length} categoría${_selectedCategories.length > 1 ? 's' : ''}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// 2. Botón visual para mostrar categorías seleccionadas (inspirado en el filtro del mapa)
  Widget _buildCategorySelectionButton(BuildContext context) => Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showCategorySelectionSheet(context),
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(
                _selectedCategories.isEmpty
                    ? Icons.category_outlined
                    : Icons.category,
                color: Colors.blueAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCategories.isEmpty
                      ? 'Seleccionar categorías'
                      : _selectedCategories.length == 1
                      ? _selectedCategories.first['name']
                      : '${_selectedCategories.length} categorías seleccionadas',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _selectedCategories.length >= 2
                      ? Colors.orange.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedCategories.length}/2',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _selectedCategories.length >= 2
                        ? Colors.orange.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );

// 3. Método para obtener iconos de categorías (necesitarás adaptarlo a tus categorías)
  IconData _getCategoryIcon(String categoryName) {
    // Mapea los nombres de tus categorías a iconos apropiados
    switch (categoryName.toLowerCase()) {
      case 'electricidad':
      case 'eléctrico':
        return Icons.electrical_services;
      case 'plomería':
      case 'fontanería':
        return Icons.plumbing;
      case 'carpintería':
      case 'madera':
        return Icons.carpenter;
      case 'pintura':
        return Icons.format_paint;
      case 'jardinería':
        return Icons.grass;
      case 'limpieza':
        return Icons.cleaning_services;
      case 'construcción':
        return Icons.construction;
      case 'tecnología':
      case 'informática':
        return Icons.computer;
      case 'mecánica':
        return Icons.build;
      case 'cocina':
      case 'gastronomía':
        return Icons.restaurant;
      case 'educación':
      case 'clases':
        return Icons.school;
      case 'salud':
      case 'cuidado':
        return Icons.health_and_safety;
      case 'transporte':
        return Icons.local_shipping;
      case 'belleza':
      case 'estética':
        return Icons.face;
      case 'mascotas':
        return Icons.pets;
      case 'eventos':
        return Icons.event;
      case 'hogar':
      case 'doméstico':
        return Icons.home_repair_service;
      case 'arte':
      case 'diseño':
        return Icons.palette;
      case 'música':
        return Icons.music_note;
      case 'deportes':
      case 'fitness':
        return Icons.fitness_center;
      default:
        return Icons.work_outline;
    }
  }

// 4. Widget para mostrar las categorías seleccionadas como chips (alternativa visual)
  Widget _buildSelectedCategoriesChips() {
    if (_selectedCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _selectedCategories.map((category) => Chip(
            avatar: Icon(
              _getCategoryIcon(category['name']),
              size: 16,
              color: Colors.blueAccent,
            ),
            label: Text(
              category['name'],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => _removeCategory(category['id']),
            backgroundColor: Colors.blue.shade50,
            deleteIconColor: Colors.red.shade400,
          ),).toList(),
      ),
    );
  }

  // Buscar categorías en tiempo real
  Future<void> _searchCategories(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearchingCategories = true);

    try {
      final categories = await _userService.searchCategories(query);
      setState(() {
        _searchResults = categories;
        _isSearchingCategories = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al buscar categorías: $e');
      }
      setState(() {
        _searchResults = [];
        _isSearchingCategories = false;
      });
    }
  }

  // Cargar oficios de una categoría específica
  Future<void> _loadOficiosForCategory(int categoryId) async {
    if (_oficiosPorCategoria.containsKey(categoryId)) {
      return; // Ya están cargados
    }

    setState(() => _isLoadingOficios = true);

    try {
      final oficios = await _userService.loadOficiosByCategory(categoryId);
      setState(() {
        _oficiosPorCategoria[categoryId] = oficios;
        _selectedOficiosPorCategoria[categoryId] = [];
        _isLoadingOficios = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar oficios: $e');
      }
      setState(() => _isLoadingOficios = false);
    }
  }

  // Añadir categoría
  void _addCategory(Map<String, dynamic> category) {
    if (_selectedCategories.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes seleccionar máximo 2 categorías principales'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_selectedCategories.any((c) => c['id'] == category['id'])) {
      setState(() {
        _selectedCategories.add(category);
      });
      _loadOficiosForCategory(category['id']);
    }
  }

  // Eliminar categoría
  void _removeCategory(int categoryId) {
    setState(() {
      _selectedCategories.removeWhere((c) => c['id'] == categoryId);
      _selectedOficiosPorCategoria.remove(categoryId);
      _oficiosPorCategoria.remove(categoryId);
    });
  }

  // Añadir oficio a una categoría
  void _addOficioToCategory(int categoryId, Map<String, dynamic> oficio) {
    final selectedOficios = _selectedOficiosPorCategoria[categoryId] ?? [];

    if (selectedOficios.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes seleccionar máximo 3 oficios por categoría'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!selectedOficios.any((o) => o['id'] == oficio['id'])) {
      setState(() {
        _selectedOficiosPorCategoria[categoryId]!.add(oficio);
      });
    }
  }

  // Eliminar oficio de una categoría
  void _removeOficioFromCategory(int categoryId, int oficioId) {
    setState(() {
      _selectedOficiosPorCategoria[categoryId]?.removeWhere((o) => o['id'] == oficioId);
    });
  }

  // Mostrar diálogo para seleccionar oficios de una categoría
  void _showOficiosDialog(Map<String, dynamic> category) {
    final categoryId = category['id'] as int;
    final oficiosDisponibles = _oficiosPorCategoria[categoryId] ?? [];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Oficios de ${category['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              // Mensaje informativo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Puedes seleccionar máximo 3 oficios',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lista de oficios
              Expanded(
                child: _isLoadingOficios
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  itemCount: oficiosDisponibles.length,
                  itemBuilder: (context, index) {
                    final oficio = oficiosDisponibles[index];
                    final isSelected = _selectedOficiosPorCategoria[categoryId]
                        ?.any((o) => o['id'] == oficio['id']) ?? false;

                    return CheckboxListTile(
                      title: Text(oficio['name']),
                      value: isSelected,
                      onChanged: (bool? value) {
                        if (value == true) {
                          _addOficioToCategory(categoryId, oficio);
                        } else {
                          _removeOficioFromCategory(categoryId, oficio['id']);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Mostrar diálogo para añadir habilidad (mantenemos el código original)
  void _showAddSkillDialog() {
    var searchResults = <Map<String, dynamic>>[];
    var isSearching = false;
    var nivel = 'Intermedio';
    final nivelesHabilidad = <String>['Principiante', 'Intermedio', 'Avanzado', 'Experto'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar habilidad'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchSkillController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar habilidad...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) async {
                    if (value.length >= 2) {
                      setDialogState(() => isSearching = true);
                      final results = await _userService.searchSkills(value);
                      setDialogState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    } else {
                      setDialogState(() => searchResults = []);
                    }
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Nivel',
                    border: OutlineInputBorder(),
                  ),
                  value: nivel,
                  items: nivelesHabilidad.map((nivelItem) => DropdownMenuItem<String>(
                    value: nivelItem,
                    child: Text(nivelItem),
                  ),).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => nivel = value);
                    }
                  },
                ),
                const SizedBox(height: 15),
                if (isSearching)
                  const Center(child: CircularProgressIndicator())
                else if (searchResults.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final skill = searchResults[index];
                        return ListTile(
                          title: Text(skill['name']),
                          trailing: Text(nivel),
                          onTap: () {
                            _addSkill(skill, nivel);
                            Navigator.pop(dialogContext);
                          },
                        );
                      },
                    ),
                  )
                else if (_searchSkillController.text.isNotEmpty)
                    Column(
                      children: [
                        const Text('No se encontraron resultados'),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            setDialogState(() => isSearching = true);
                            try {
                              final newSkill = await _userService.createNewSkill(_searchSkillController.text);
                              if (newSkill != null) {
                                await _addSkill(newSkill, nivel);
                              }
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            } catch (e) {
                              if (kDebugMode) {
                                print('Error: $e');
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error al crear habilidad: $e')),
                                );
                              }
                            } finally {
                              setDialogState(() => isSearching = false);
                            }
                          },
                          child: const Text('Crear nueva habilidad'),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    ).then((_) => _searchSkillController.clear());
  }

  // Añadir habilidad (código original)
  Future<void> _addSkill(Map<String, dynamic> skill, String nivel) async {
    try {
      if (_userSkills.any((s) => s['id'] == skill['id'])) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya tienes esta habilidad')),
          );
        }
        return;
      }

      await _userService.addUserSkill(skill['id'], nivel);

      if (mounted) {
        setState(() {
          _userSkills.add({
            'id': skill['id'],
            'name': skill['name'],
            'nivel': nivel,
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilidad agregada')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al agregar habilidad: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Eliminar habilidad (código original)
  Future<void> _removeSkill(int skillId) async {
    try {
      await _userService.removeUserSkill(skillId);

      if (mounted) {
        setState(() {
          _userSkills.removeWhere((s) => s['id'] == skillId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilidad eliminada')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar habilidad: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar habilidad: $e')),
        );
      }
    }
  }

  // Finalizar registro - VERSIÓN SIMPLIFICADA con logs de debug
  Future<void> _finishRegistration() async {
    if (kDebugMode) {
      print('🚀 Iniciando _finishRegistration...');
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una categoría')),
      );
      return;
    }

    // Verificar que al menos una categoría tenga oficios seleccionados
    var hasOficios = false;
    for (final category in _selectedCategories) {
      final categoryId = category['id'] as int;
      if (_selectedOficiosPorCategoria[categoryId]?.isNotEmpty == true) {
        hasOficios = true;
        break;
      }
    }

    if (!hasOficios) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un oficio')),
      );
      return;
    }

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finalizando registro...')),
        );
      }

      if (kDebugMode) {
        print('💾 Guardando datos del perfil...');
      }

      // Actualizar los datos del perfil local
      widget.userProfile.categories = _selectedCategories;
      widget.userProfile.skills = _userSkills;

      // Guardar categorías y oficios
      await _userService.saveUserCategoriesWithOficios(
          _selectedCategories,
          _selectedOficiosPorCategoria,
          widget.userProfile
      );

      if (kDebugMode) {
        print('💾 Actualizando perfil de usuario...');
      }

      // Actualizar el perfil completo
      await _userService.updateUserProfile(widget.userProfile);

      if (kDebugMode) {
        print('✅ Datos guardados, llamando a widget.onCompleted()...');
      }

      if (context.mounted) {
        await widget.onCompleted(); // ← CAMBIO AQUÍ: agregar await
      }

      if (kDebugMode) {
        print('📞 widget.onCompleted() ejecutado y completado');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al finalizar registro: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar registro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona tus preferencias'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mensaje informativo principal
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        'Configuración de perfil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Máximo 2 categorías principales\n• Máximo 3 oficios por categoría',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Sección de categorías
                Row(
                  children: [
                    const Text(
                      'Categorías principales',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedCategories.length}/2',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Botón de selección de categorías (estilo filtro del mapa)
                _buildCategorySelectionButton(context),

                // Mostrar categorías seleccionadas como chips
                _buildSelectedCategoriesChips(),

                const SizedBox(height: 10),

                // Mostrar categorías seleccionadas con sus oficios
                if (_selectedCategories.isEmpty)
                  const Text(
                    'Selecciona al menos una categoría',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ..._selectedCategories.map((category) => _buildCategoryCard(category)),

                const SizedBox(height: 30),

                // Sección de habilidades
                const Text(
                  'Tus habilidades',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),

                ElevatedButton.icon(
                  onPressed: () => _showAddSkillDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir habilidad'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._userSkills.map((skill) => Chip(
                      label: Text("${skill['name']} (${skill['nivel']})"),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSkill(skill['id']),
                      backgroundColor: Colors.blue.shade100,
                      labelStyle: const TextStyle(color: Colors.blue),
                    ),),
                    if (_userSkills.isEmpty)
                      const Text(
                        'Añade algunas de tus habilidades',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),

                const SizedBox(height: 40),

                // Botón para finalizar
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _finishRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'FINALIZAR REGISTRO',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white,
    );

  // Widget para mostrar cada categoría con sus oficios
  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final categoryId = category['id'] as int;
    final selectedOficios = _selectedOficiosPorCategoria[categoryId] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de la categoría
            Row(
              children: [
                Expanded(
                  child: Text(
                    category['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedOficios.length}/3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _removeCategory(categoryId),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Botón para seleccionar oficios
            ElevatedButton.icon(
              onPressed: () => _showOficiosDialog(category),
              icon: const Icon(Icons.work_outline),
              label: Text(
                selectedOficios.isEmpty
                    ? 'Seleccionar oficios'
                    : 'Editar oficios (${selectedOficios.length})',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.grey.shade700,
                elevation: 0,
              ),
            ),
            const SizedBox(height: 8),

            // Mostrar oficios seleccionados
            if (selectedOficios.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedOficios.map((oficio) => Chip(
                  label: Text(
                    oficio['name'],
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green.shade50,
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _removeOficioFromCategory(categoryId, oficio['id']),
                ),).toList(),
              )
            else
              const Text(
                'No has seleccionado oficios para esta categoría',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}