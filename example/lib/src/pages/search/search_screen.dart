import 'package:flutter/material.dart';

import '../../services/search_service.dart';
import '../../services/user_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final SearchService _searchService = SearchService();

  // Estado
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _oficios = []; // Oficios cargados según categoría
  
  // Selección
  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _selectedOficio;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Reutilizamos tu UserService existente
      final categories = await _userService.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando filtros: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onCategorySelected(Map<String, dynamic> category) async {
    // Si deselecciona
    if (_selectedCategory == category) {
      setState(() {
        _selectedCategory = null;
        _selectedOficio = null;
        _oficios = [];
      });
      return;
    }

    setState(() {
      _selectedCategory = category;
      _selectedOficio = null; // Reset oficio
      _isLoading = true;
    });

    // Cargar oficios de esta categoría
    try {
      final oficios = await _userService.loadOficiosByCategory(category['id']);
      if (mounted) {
        setState(() {
          _oficios = oficios;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando oficios: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _performSearch() {
    final query = _searchController.text;
    
    // Guardar historial (Fire & Forget)
    _searchService.logSearch(
      query: query,
      filters: {
        if (_selectedCategory != null) 'category_id': _selectedCategory!['id'],
        if (_selectedCategory != null) 'category_name': _selectedCategory!['name'],
        if (_selectedOficio != null) 'oficio_id': _selectedOficio!['id'],
        if (_selectedOficio != null) 'oficio_name': _selectedOficio!['name'],
      },
    );

    // Regresar a la pantalla principal con los datos
    Navigator.pop(context, {
      'query': query,
      'category': _selectedCategory,
      'oficio': _selectedOficio,
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true, // ¡Teclado arriba apenas abre!
          decoration: const InputDecoration(
            hintText: '¿Qué servicio buscas?',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 18),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue),
            onPressed: _performSearch,
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECCIÓN: CATEGORÍAS
                  const Text(
                    'Filtrar por Categoría',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat['name']),
                        selected: isSelected,
                        onSelected: (_) => _onCategorySelected(cat),
                        selectedColor: Colors.blue.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.blue.shade800 : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),

                  // SECCIÓN: OFICIOS (Solo aparece si hay categoría seleccionada)
                  if (_selectedCategory != null && _oficios.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Especialidad en ${_selectedCategory!['name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _oficios.map((oficio) {
                        final isSelected = _selectedOficio == oficio;
                        return ChoiceChip(
                          label: Text(oficio['name']),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedOficio = selected ? oficio : null;
                            });
                          },
                          selectedColor: Colors.green.shade100,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.green.shade800 : Colors.black87,
                          ),
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
}