import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/user_service.dart';

class UpdateCategoriesScreen extends StatefulWidget {
  const UpdateCategoriesScreen({super.key});

  @override
  State<UpdateCategoriesScreen> createState() => _UpdateCategoriesScreenState();
}

class _UpdateCategoriesScreenState extends State<UpdateCategoriesScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();

  // Agregar después de las variables existentes
  List<Map<String, dynamic>> _allCategories = [];
  bool _isLoadingCategories = false;

  // Estado de la pantalla
  bool _isLoading = false;
  bool _hasChanges = false;

  // Datos
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _selectedCategories = [];
  Map<int, List<Map<String, dynamic>>> _oficiosPorCategoria = {};
  final Map<int, List<Map<String, dynamic>>> _allOficiosPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Método para cargar todas las categorías disponibles
  Future<void> _loadAllCategories() async {
    setState(() => _isLoadingCategories = true);

    try {
      final categories = await _userService.getAllCategories();
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

// Método para mostrar el modal de categorías
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

            // Lista de todas las categorías
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

                  return ListTile(
                    leading: Icon(
                      _getCategoryIcon(category['name']),
                      color: isAlreadySelected
                          ? Colors.green
                          : Colors.blueAccent,
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
                        : const Icon(Icons.add, color: Colors.blueAccent),
                    onTap: isAlreadySelected
                        ? null
                        : () {
                      _addCategory(category);
                      setState(() {}); // Actualizar el estado
                    },
                    enabled: !isAlreadySelected,
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
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Método para obtener iconos de categorías
  IconData _getCategoryIcon(String categoryName) {
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

// Widget para el botón de categorías
  Widget _buildCategorySelectionButton(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8, bottom: 16),
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
              Icons.category,
              color: Colors.blueAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ver todas las categorías',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
          ],
        ),
      ),
    ),
  );

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Cargar categorías del usuario
      final userCategoriesData = await _userService.getUserCategoriesWithOficios();

      setState(() {
        _selectedCategories = List.from(userCategoriesData['categories'] ?? []);
        _oficiosPorCategoria = Map.from(userCategoriesData['oficiosPorCategoria'] ?? {});
        _isLoading = false;
      });

      // Cargar oficios para las categorías seleccionadas
      await _loadOficiosForSelectedCategories();

      // Cargar todas las categorías para el botón desplegable
      await _loadAllCategories();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error al cargar datos: $e');
    }
  }

  Future<void> _loadOficiosForSelectedCategories() async {
    for (var category in _selectedCategories) {
      await _loadOficiosForCategory(category['id']);
    }
  }

  Future<void> _loadOficiosForCategory(int categoryId) async {
    try {
      final oficios = await _userService.loadOficiosByCategory(categoryId);
      setState(() {
        _allOficiosPorCategoria[categoryId] = oficios;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar oficios para categoría $categoryId: $e');
      }
    }
  }

  Future<void> _searchCategories(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final results = await _userService.searchCategories(query);
      setState(() => _searchResults = results);
    } catch (e) {
      _showErrorSnackBar('Error al buscar categorías: $e');
    }
  }

  void _addCategory(Map<String, dynamic> category) async {
    // Verificar si ya está seleccionada
    if (_selectedCategories.any((c) => c['id'] == category['id'])) {
      _showErrorSnackBar('Esta categoría ya está seleccionada');
      return;
    }

    setState(() {
      _selectedCategories.add(category);
      _hasChanges = true;
      _searchController.clear();
      _searchResults = [];
    });

    // Cargar oficios para la nueva categoría
    await _loadOficiosForCategory(category['id']);
  }

  void _removeCategory(int categoryId) {
    setState(() {
      _selectedCategories.removeWhere((c) => c['id'] == categoryId);
      _oficiosPorCategoria.remove(categoryId);
      _allOficiosPorCategoria.remove(categoryId);
      _hasChanges = true;
    });
  }

  void _toggleOficio(int categoryId, Map<String, dynamic> oficio) {
    setState(() {
      _oficiosPorCategoria[categoryId] ??= [];

      final oficiosList = _oficiosPorCategoria[categoryId]!;
      final existingIndex = oficiosList.indexWhere((o) => o['id'] == oficio['id']);

      if (existingIndex >= 0) {
        oficiosList.removeAt(existingIndex);
      } else {
        // Limitar a máximo 3 oficios por categoría
        if (oficiosList.length >= 3) {
          _showErrorSnackBar('Solo puedes seleccionar máximo 3 oficios por categoría');
          return;
        }
        oficiosList.add(oficio);
      }

      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      await _userService.saveUserCategoriesWithOficios(
        _selectedCategories,
        _oficiosPorCategoria,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Especialidades guardadas correctamente')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error al guardar: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Tienes cambios sin guardar. ¿Deseas descartarlos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Especialidades'),
          foregroundColor: Colors.black,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _saveChanges,
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // Buscador de categorías
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buscar categorías',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Ej: Construcción, Electricidad...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: _searchCategories,
                  ),

                  // Botón para ver todas las categorías
                  _buildCategorySelectionButton(context),

                  // Resultados de búsqueda
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final category = _searchResults[index];
                          final isSelected = _selectedCategories
                              .any((c) => c['id'] == category['id']);

                          return ListTile(
                            title: Text(category['name']),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Colors.green)
                                : const Icon(Icons.add),
                            onTap: isSelected ? null : () => _addCategory(category),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Lista de categorías seleccionadas
            Expanded(
              child: _selectedCategories.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _selectedCategories.length,
                itemBuilder: (context, index) {
                  final category = _selectedCategories[index];
                  return _buildCategoryCard(category);
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _hasChanges
            ? Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Guardar cambios',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        )
            : null,
      ),
    );

  Widget _buildEmptyState() => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes especialidades',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Busca y agrega las categorías en las que trabajas',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final categoryId = category['id'] as int;
    final oficiosDisponibles = _allOficiosPorCategoria[categoryId] ?? [];
    final oficiosSeleccionados = _oficiosPorCategoria[categoryId] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de la categoría
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.category,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeCategory(categoryId),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Eliminar categoría',
                ),
              ],
            ),

            if (oficiosDisponibles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Oficios (máximo 3):',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Lista de oficios disponibles
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: oficiosDisponibles.map((oficio) {
                  final isSelected = oficiosSeleccionados
                      .any((o) => o['id'] == oficio['id']);

                  return FilterChip(
                    label: Text(oficio['name']),
                    selected: isSelected,
                    onSelected: (_) => _toggleOficio(categoryId, oficio),
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade700,
                    side: BorderSide(
                      color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                    ),
                  );
                }).toList(),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No hay oficios disponibles para esta categoría',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}