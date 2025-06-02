// Archivo: lib/widgets/category_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../managers/workers_filter_manager.dart';

class CategoryDrawer extends StatelessWidget {
  const CategoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener el manager de filtros
    final filterManager = Provider.of<WorkersFilterManager>(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Filtrar por Categoría',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Categoría actual: ${filterManager.selectedCategory}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: filterManager.categories.map((category) => ListTile(
                title: Text(category),
                leading: Icon(
                  filterManager.getCategoryIcon(category),
                  color: filterManager.selectedCategory == category
                      ? Colors.blueAccent
                      : Colors.grey,
                ),
                selected: filterManager.selectedCategory == category,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                onTap: () {
                  // Al seleccionar una categoría, actualizar el filtro y cerrar el drawer
                  filterManager.setCategory(category);
                  Navigator.pop(context);
                },
              ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}