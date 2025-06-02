import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Clase para gestionar los filtros de trabajadores
class WorkersFilterManager extends ChangeNotifier {
  // Listas de filtros disponibles
  List<String> _categories = ['Todos'];
  List<String> _skills = ['Todas']; // Lista para oficios/habilidades
  List<Map<String, dynamic>> _categoriesList = [];
  List<Map<String, dynamic>> _skillsList = []; // Lista para datos de oficios

  // Getters
  List<String> get categories => _categories;
  List<String> get skills => _skills;
  String get selectedCategory => _selectedCategory;
  String get selectedSkill => _selectedSkill;
  List<Map<String, dynamic>>? get nearbyWorkers => _nearbyWorkers;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Estado del filtro
  String _selectedCategory = 'Todos';
  String _selectedSkill = 'Todas';
  List<Map<String, dynamic>>? _nearbyWorkers;
  bool _isLoading = true;
  String _errorMessage = '';

  // Constructor con valores iniciales opcionales
  WorkersFilterManager({
    String initialCategory = 'Todos',
    String initialSkill = 'Todas',
    bool initialLoading = true,
  }) :
        _selectedCategory = initialCategory,
        _selectedSkill = initialSkill,
        _isLoading = initialLoading {
    // Cargar categorías y oficios al inicializar
    _fetchCategories();
    _fetchSkills();
  }

  // Métodos para manipular el estado
  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;

      // Si cambia la categoría, filtrar los oficios por esa categoría
      if (category == 'Todos') {
        // Mostrar todos los oficios
        _skills = ['Todas'] + _skillsList.map((s) => s['name'] as String).toList();
      } else {
        // Filtrar oficios por categoría seleccionada
        final categoryId = _getCategoryId(category);
        if (categoryId != null) {
          final filteredSkills = _skillsList
              .where((skill) => skill['category_id'] == categoryId)
              .map((skill) => skill['name'] as String)
              .toList();
          _skills = ['Todas'] + filteredSkills;
        }
      }

      // Resetear la habilidad seleccionada si ya no está disponible
      if (!_skills.contains(_selectedSkill)) {
        _selectedSkill = 'Todas';
      }

      notifyListeners();
    }
  }

  void setSkill(String skill) {
    if (_selectedSkill != skill) {
      _selectedSkill = skill;
      notifyListeners();
    }
  }

  void setNearbyWorkers(List<Map<String, dynamic>> workers) {
    _nearbyWorkers = workers;
    notifyListeners();
  }

  void setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  void setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Método auxiliar para obtener el ID de una categoría
  int? _getCategoryId(String categoryName) {
    try {
      final category = _categoriesList.firstWhere(
            (c) => c['name'] == categoryName,
      );
      return category['id'] as int;
    } catch (e) {
      return null;
    }
  }

  // Métodos para obtener datos desde Supabase
  Future<void> _fetchCategories() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .schema('jobs')
          .from('categories')
          .select('id, name')
          .order('name');

      setState(() {
        _categoriesList = response.map((c) => {
          'id': c['id'] as int,
          'name': c['name'] as String,
          },
        ).toList();

        _categories = ['Todos'] + _categoriesList.map((c) => c['name'] as String).toList();
      });

      if (kDebugMode) {
        print('Categorías cargadas: ${_categories.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando categorías: $e');
      }
      setErrorMessage('Error cargando categorías');
    }
  }

  Future<void> _fetchSkills() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .schema('jobs')
          .from('oficios')
          .select('id, name, category_id')
          .order('name');

      setState(() {
        _skillsList = response.map((o) => {
          'id': o['id'] as int,
          'name': o['name'] as String,
          'category_id': o['category_id'] as int,
          },
        ).toList();

        // Inicialmente mostrar todos los oficios
        _skills = ['Todas'] + _skillsList.map((o) => o['name'] as String).toList();
      });

      if (kDebugMode) {
        print('Oficios cargados: ${_skillsList.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando oficios: $e');
      }
      setErrorMessage('Error cargando oficios');
    }
  }

  // Método para actualizar el estado (similar a setState pero para ChangeNotifier)
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  // Método para filtrar trabajadores por categoría y habilidad
  List<Map<String, dynamic>> filterWorkersByCategory(List<Map<String, dynamic>> workers) {
    List<Map<String, dynamic>> filteredWorkers = workers;

    // Filtrar por categoría
    if (_selectedCategory != 'Todos') {
      filteredWorkers = filteredWorkers.where((worker) =>
      worker['category'] == _selectedCategory,
      ).toList();
    }

    // Filtrar por oficio/habilidad
    if (_selectedSkill != 'Todas') {
      filteredWorkers = filteredWorkers.where((worker) =>
      worker['skill'] == _selectedSkill ||
          worker['oficio'] == _selectedSkill ||
          // También puedes buscar en un array de habilidades si los trabajadores tienen múltiples oficios
          (worker['skills'] != null && worker['skills'].contains(_selectedSkill)),
      ).toList();
    }

    return filteredWorkers;
  }

  // Método para obtener el icono de cada categoría
  IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'todos':
        return Icons.work;
      case 'plomería':
      case 'plomeria':
        return Icons.plumbing;
      case 'electricidad':
        return Icons.electric_bolt;
      case 'carpintería':
      case 'carpinteria':
        return Icons.handyman;
      case 'albañilería':
      case 'albañileria':
        return Icons.construction;
      case 'jardinería':
      case 'jardineria':
        return Icons.grass;
      case 'limpieza':
        return Icons.cleaning_services;
      case 'pintura':
        return Icons.format_paint;
      default:
        return Icons.category;
    }
  }

  // Método para obtener el icono de cada oficio/habilidad
  IconData getSkillIcon(String skill) {
    switch (skill.toLowerCase()) {
      case 'todas':
        return Icons.star;
    // Oficios de plomería
      case 'reparación de tuberías':
      case 'reparacion de tuberias':
        return Icons.plumbing;
      case 'instalación de grifos':
      case 'instalacion de grifos':
        return Icons.water_drop;
      case 'destape de cañerías':
      case 'destape de canerias':
        return Icons.cleaning_services;
    // Oficios de electricidad
      case 'instalación eléctrica':
      case 'instalacion electrica':
        return Icons.electrical_services;
      case 'reparación de enchufes':
      case 'reparacion de enchufes':
        return Icons.power;
      case 'instalación de luces':
      case 'instalacion de luces':
        return Icons.lightbulb;
    // Oficios de carpintería
      case 'muebles a medida':
        return Icons.chair;
      case 'reparación de puertas':
      case 'reparacion de puertas':
        return Icons.door_front_door;
      case 'instalación de pisos':
      case 'instalacion de pisos':
        return Icons.layers;
    // Oficios de construcción/albañilería
      case 'construcción de muros':
      case 'construccion de muros':
        return Icons.foundation;
      case 'reparación de techos':
      case 'reparacion de techos':
        return Icons.roofing;
      case 'pintura de paredes':
        return Icons.format_paint;
    // Oficios de jardinería
      case 'poda de árboles':
      case 'poda de arboles':
        return Icons.park;
      case 'instalación de césped':
      case 'instalacion de cesped':
        return Icons.grass;
      case 'diseño de jardines':
      case 'diseno de jardines':
        return Icons.yard;
    // Oficios de limpieza
      case 'limpieza profunda':
        return Icons.cleaning_services;
      case 'limpieza de ventanas':
        return Icons.window;
      case 'limpieza de alfombras':
        return Icons.wash;
    // Iconos por defecto
      default:
        return Icons.build;
    }
  }

  // Determinar el sector geográfico
  String determineSector(LatLng position) {
    // Dividir el área en 4 cuadrantes
    final centerLat = position.latitude;
    final centerLon = position.longitude;

    if (position.latitude >= centerLat && position.longitude >= centerLon) {
      return 'Noreste';
    } else if (position.latitude >= centerLat && position.longitude < centerLon) {
      return 'Noroeste';
    } else if (position.latitude < centerLat && position.longitude >= centerLon) {
      return 'Sureste';
    } else {
      return 'Suroeste';
    }
  }
}