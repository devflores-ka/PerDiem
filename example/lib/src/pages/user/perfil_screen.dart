// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  // Datos del usuario
  String? firstName = '';
  String? lastName = '';
  String? imageUrl = 'https://placehold.co/100';
  String? descripcion = '';
  bool isLoading = true;

  // Lista de habilidades del usuario
  List<Map<String, dynamic>> userSkills = [];
  // Lista de todas las habilidades disponibles (para búsqueda)
  List<Map<String, dynamic>> allSkills = [];
  // Niveles de habilidad disponibles
  final List<String> nivelesHabilidad = ['Principiante', 'Intermedio', 'Avanzado', 'Experto'];

  // Para edición
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _searchSkillController = TextEditingController();
  final _nivelSeleccionado = 'Intermedio'; // Nivel por defecto

  // Para la edición de descripción inline
  bool _isEditingDescription = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatosUsuario();
    _cargarHabilidadesUsuario();
    _cargarTodasHabilidades();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descripcionController.dispose();
    _searchSkillController.dispose();
    super.dispose();
  }

  // Cargar datos del usuario desde Supabase
  Future<void> _cargarDatosUsuario() async {
    setState(() => isLoading = true);

    try {
      // Obtener el usuario actual
      final user = supabase.auth.currentUser;

      if (user != null) {
        // Consultar los datos del usuario
        final userData = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl, descripcion')
            .eq('id', user.id)
            .single();

        setState(() {
          firstName = userData['firstName'];
          lastName = userData['lastName'];
          imageUrl = userData['imageUrl'];
          descripcion = userData['descripcion'] ?? 'Sin descripción';
          _descripcionController.text = descripcion!;
          isLoading = false;
        });
      } else {
        // Si no hay usuario autenticado
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error al cargar datos del usuario: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _cargarHabilidadesUsuario() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Debug output before query
      if (kDebugMode) {
        print('Cargando habilidades para usuario: ${user.id}');
      }

      // Consulta para obtener habilidades del usuario con nivel
      final data = await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .select('habilidad_id, nivel, habilidades:habilidad_id(id, name)')
          .eq('user_id', user.id);

      // Debug: print raw data
      if (kDebugMode) {
        print('Datos de habilidades obtenidos: $data');
      }

      // Transformar datos para un formato más usable
      final List<Map<String, dynamic>> skills = [];
      for (var item in data) {
        // Check if habilidades data exists before accessing it
        if (item['habilidades'] != null) {
          skills.add({
            'id': item['habilidad_id'],
            'name': item['habilidades']['name'],
            'nivel': item['nivel'] ?? 'Intermedio' // Default level if null
          });
        }
      }

      if (kDebugMode) {
        print('Habilidades procesadas: $skills');
      }
      setState(() => userSkills = skills);
    } catch (e) {
      debugPrint('Error al cargar habilidades del usuario: $e');
      // Show error details in console
      if (kDebugMode) {
        print('Error completo: $e');
      }
    }
  }

  // Cargar todas las habilidades disponibles
  Future<void> _cargarTodasHabilidades() async {
    try {
      // Consulta para obtener todas las habilidades
      final data = await supabase
          .schema('jobs')
          .from('habilidades')
          .select('id, name')
          .limit(100);

      setState(() => allSkills = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error al cargar todas las habilidades: $e');
    }
  }

  // Buscar habilidades disponibles
  Future<List<Map<String, dynamic>>> _buscarHabilidades(String query) async {
    try {
      // Buscar habilidades que coincidan con la consulta
      final data = await supabase
          .schema('jobs')
          .from('habilidades')
          .select('id, name')
          .ilike('name', '%$query%')
          .limit(10);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error al buscar habilidades: $e');
      return [];
    }
  }

  // Crear una nueva habilidad en el catálogo
  Future<Map<String, dynamic>?> _crearNuevaHabilidad(String skillName) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // Insertar nueva habilidad en el catálogo incluyendo user_id
      final result = await supabase
          .schema('jobs')
          .from('habilidades')
          .insert({
        'name': skillName,
        'user_id': user.id  // Campo requerido
      })
          .select()
          .single();

      return result;
    } catch (e) {
      debugPrint('Error al crear nueva habilidad: $e');
      return null;
    }
  }

// Agregar una habilidad al usuario
  Future<void> _agregarHabilidadUsuario(int habilidadId, String nivel) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Verificar si el usuario ya tiene esta habilidad
      final existingSkills = await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .select()
          .eq('habilidad_id', habilidadId)
          .eq('user_id', user.id);

      if (existingSkills.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya tienes esta habilidad en tu perfil')),
          );
        }
        return;
      }

      // Insertar en la tabla intermedia
      await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .insert({
        'habilidad_id': habilidadId,
        'user_id': user.id,
        'habilidades_id': habilidadId, // Parece que tu esquema requiere esto
        'nivel': nivel
      });

      // Recargar habilidades del usuario
      await _cargarHabilidadesUsuario();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilidad agregada correctamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agregar habilidad: $e')),
        );
      }
    }
  }

  // Eliminar una habilidad del usuario
  Future<void> _eliminarHabilidadUsuario(int habilidadId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Eliminar de la tabla intermedia
      await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .delete()
          .eq('habilidad_id', habilidadId)
          .eq('user_id', user.id);

      // Actualizar la lista de habilidades
      setState(() {
        userSkills.removeWhere((skill) => skill['id'] == habilidadId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habilidad eliminada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar habilidad: $e')),
      );
    }
  }

  // Actualizar la descripción del usuario
  Future<void> _actualizarDescripcion(String nuevaDescripcion) async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      await supabase
          .schema('chats')
          .from('users')
          .update({'descripcion': nuevaDescripcion})
          .eq('id', user.id);

      setState(() => descripcion = nuevaDescripcion);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descripción actualizada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  // Actualizar la foto de perfil
  Future<void> _actualizarFotoPerfil() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery);

    if (imagen == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Mostrar indicador de carga
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
      );

      // Ruta para almacenar la imagen en Storage
      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}${path.extension(imagen.path)}';
      final storageUrl = 'user_profiles/$fileName';

      // Subir imagen a Storage
      final file = File(imagen.path);
      await supabase.storage.from('avatars').upload(storageUrl, file);

      // Obtener URL pública
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(storageUrl);

      // Actualizar referencia en la base de datos
      await supabase
          .schema('chats')
          .from('users')
          .update({'imageUrl': publicUrl})
          .eq('id', user.id);

      // Actualizar estado
      setState(() => imageUrl = publicUrl);

      // Cerrar el diálogo de carga
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      // Cerrar el diálogo de carga en caso de error
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar foto: $e')),
      );
    }
  }

  // Diálogo para añadir habilidades
  void _mostrarDialogoAgregarHabilidad() {
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    String nivel = _nivelSeleccionado;

    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar habilidad'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo de búsqueda
                TextField(
                  controller: _searchSkillController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar habilidad...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) async {
                    if (value.length >= 2) {
                      setState(() => isSearching = true);
                      final results = await _buscarHabilidades(value);
                      setState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    } else {
                      setState(() => searchResults = []);
                    }
                  },
                ),
                const SizedBox(height: 15),

                // Selector de nivel
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Nivel',
                    border: OutlineInputBorder(),
                  ),
                  value: nivel,
                  items: nivelesHabilidad.map((nivelItem) => DropdownMenuItem<String>(
                    value: nivelItem,
                    child: Text(nivelItem),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => nivel = value);
                    }
                  },
                ),
                const SizedBox(height: 15),

                // Resultados de búsqueda
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
                            _agregarHabilidadUsuario(skill['id'], nivel);
                            Navigator.pop(context);
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
                            // Mostrar indicador de carga
                            setState(() => isSearching = true);

                            try {
                              // Crear primero la habilidad
                              final newSkill = await _crearNuevaHabilidad(_searchSkillController.text);

                              // Luego asociarla al usuario si se creó correctamente
                              if (newSkill != null) {
                                await _agregarHabilidadUsuario(newSkill['id'], nivel);
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              debugPrint('Error al crear y asignar habilidad: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              // Desactivar indicador de carga si el diálogo sigue abierto
                              if (context.mounted) {
                                setState(() => isSearching = false);
                              }
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Limpiar el campo de búsqueda al cerrar el diálogo
      _searchSkillController.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Perfil'),
    ),
    backgroundColor: Colors.white,
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto de perfil con opción para cambiar
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(imageUrl ?? 'https://placehold.co/100'),
                onBackgroundImageError: (_, __) => const Icon(Icons.error),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _actualizarFotoPerfil,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nombre desde Supabase
          Text(
            '$firstName $lastName',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text('Usuario', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 5),
              Text('4.8', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 5),
              Text('(124 reviews)', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),

          // Sección "Sobre mí" con edición inline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sobre mí',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(
                    _isEditingDescription ? Icons.check : Icons.edit,
                    size: 18
                ),
                onPressed: () {
                  if (_isEditingDescription) {
                    // Guardar cambios
                    _actualizarDescripcion(_descripcionController.text);
                  }
                  setState(() {
                    _isEditingDescription = !_isEditingDescription;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Campo de descripción editable/no editable
          _isEditingDescription
              ? TextField(
            controller: _descripcionController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Escribe algo sobre ti...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
          )
              : Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              descripcion ?? 'Sin descripción',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 15),

          // Skills con botón de añadir
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Habilidades',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _mostrarDialogoAgregarHabilidad,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...userSkills.map((skill) => _buildSkillChip(
                skill['name'],
                nivel: skill['nivel'],
                onDeleted: () => _eliminarHabilidadUsuario(skill['id']),
              )).toList(),
              if (userSkills.isEmpty)
                const Text('No hay habilidades añadidas', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Trabajos'),
              Tab(text: 'Comentarios'),
              Tab(text: 'Ajustes'),
            ],
          ),

          // Contenido de los tabs
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrabajos(),
                const Center(child: Text('Comentarios')),
                const Center(child: Text('Ajustes')),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );

  // Lista de trabajos completados

  Widget _buildTrabajos() => Column(
    children: [
      _buildTrabajoItem('Flete a La Tirana', 'Completado en Marzo 15, 2025'),
      _buildTrabajoItem('Armado de andamios', 'Completado en Febrero 28, 2025'),
      _buildTrabajoItem('Chofer camión aljibe', 'Completado en Enero 20, 2025'),
    ],
  );

  Widget _buildSkillChip(String skill, {required String nivel, VoidCallback? onDeleted}) {
    // Colores del mockup
    final chipColor = Color(0xFFEFF6FF);
    final textColor = Color(0xFF2563EB);

    return Chip(
      label: Text(skill, style: TextStyle(color: textColor)),
      backgroundColor: chipColor,
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  // Widget para cada trabajo
  Widget _buildTrabajoItem(String titulo, String fecha) => Card(
    margin: const EdgeInsets.symmetric(vertical: 5),
    child: ListTile(
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(fecha),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Completado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      ),
    ),
  );
}