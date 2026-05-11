import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:perdiem_app/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/user_profile.dart';

class UserService {
  final supabase = Supabase.instance.client;

  // Buscar categorías por nombre
  Future<List<Map<String, dynamic>>> searchCategories(String query) async {
    try {
      final data = await supabase
          .schema('jobs')
          .from('categories')
          .select('id, name')
          .ilike('name', '%$query%')
          .order('name')
          .limit(10); // Limitar resultados para mejor rendimiento

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Error al buscar categorías: $e');
    }
  }

  // Cargar oficios por categoría
  Future<List<Map<String, dynamic>>> loadOficiosByCategory(int categoryId) async {
    try {
      final data = await supabase
          .schema('jobs')
          .from('oficios')
          .select('id, name')
          .eq('category_id', categoryId)
          .order('name');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Error al cargar oficios: $e');
    }
  }

  // Guardar categorías del usuario con sus oficios - VERSIÓN SÚPER SIMPLIFICADA
  Future<void> saveUserCategoriesWithOficios(
      List<Map<String, dynamic>> categories,
      Map<int, List<Map<String, dynamic>>> oficiosPorCategoria,
      [UserProfile? userProfile] // Ya no lo necesitamos, pero lo mantenemos por compatibilidad
      )
  async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    try {
      if (kDebugMode) {
        print('💾 Guardando categorías y oficios para usuario: ${user.id}');
        print('📊 Categorías: ${categories.length}');
      }

      // YA NO NECESITAMOS CREAR NADA EN chats.users
      // El trigger handle_new_user lo hace automáticamente

      // Eliminar datos existentes
      await supabase
          .schema('jobs')
          .from('user_categories')
          .delete()
          .eq('user_id', user.id);

      await supabase
          .schema('jobs')
          .from('user_oficios')
          .delete()
          .eq('user_id', user.id);

      // Insertar categorías
      for (final category in categories) {
        await supabase
            .schema('jobs')
            .from('user_categories')
            .insert({
          'user_id': user.id, // Este ID siempre existe en auth.users
          'category_id': category['id'],
        });

        // Insertar oficios para esta categoría
        final oficios = oficiosPorCategoria[category['id']] ?? [];
        for (final oficio in oficios) {
          await supabase
              .schema('jobs')
              .from('user_oficios')
              .insert({
            'user_id': user.id, // Este ID siempre existe en auth.users
            'category_id': category['id'],
            'oficio_id': oficio['id'],
          });
        }
      }

      if (kDebugMode) {
        print('✅ Categorías y oficios guardados exitosamente');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error detallado al guardar categorías y oficios: $e');
      }
      throw Exception('Error al guardar categorías y oficios: $e');
    }
  }

  // Actualizar datos del perfil
  Future<void> updateUserProfile(UserProfile profile) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa');

    try {
      // 1. Actualizar metadatos en Auth (Mantenemos esto)
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'first_name': profile.firstName,
            'last_name': profile.lastName,
            'image_url': profile.imageUrl,
            'descripcion': profile.descripcion,
            'role': profile.role,
          },
        ),
      );

      // 2. Actualizar en SupabaseChatCore (Mantenemos esto para el chat)
      await SupabaseChatCore.instance.updateUser(
        types.User(
          id: user.id,
          firstName: profile.firstName,
          lastName: profile.lastName,
          imageUrl: profile.imageUrl,
          metadata: {
            'descripcion': profile.descripcion,
            'role': profile.role,
          },
        ),
      );

      // ✅ NUEVO: Forzar actualización de la columna 'role' en chats.users
      // Esto asegura que el Panel de Admin vea el rol correctamente
      await supabase.schema('chats').from('users').update({
        'role': profile.role ?? 'user', // Si es null, ponemos 'user'
        'firstName': profile.firstName, // Ya que estamos, aseguramos el nombre
        'lastName': profile.lastName,
      }).eq('id', user.id);

      if (kDebugMode) {
        print('✅ Perfil y Rol actualizados exitosamente');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al actualizar perfil: $e');
      }
      rethrow;
    }
  }

  /// Guarda los datos personales del usuario en la base de datos
  Future<void> savePersonalData(Map<String, dynamic> personalData) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'Usuario no autenticado';
      }

      if (kDebugMode) {
        print('💾 Guardando datos personales para usuario: $userId');
        print('📊 Datos a guardar: $personalData');
      }

      // Preparar los datos para inserción
      final dataToInsert = {
        'user_id': userId,
        'phone': personalData['phone'],
        'birth_date': personalData['birth_date'],
        'marital_status': personalData['marital_status'],
        'gender': personalData['gender'],
        'address': personalData['address'],
        'city': personalData['city'],
        'country': personalData['country'],
        'region': personalData['region'],
        'emergency_contact': personalData['emergency_contact'],
        'emergency_phone': personalData['emergency_phone'],
      };

      // Limpiar valores nulos o vacíos opcionales
      dataToInsert.removeWhere((key, value) =>
      (key == 'address' || key == 'emergency_contact' || key == 'emergency_phone') &&
          (value == null || value.toString().trim().isEmpty),);

      // Verificar si ya existen datos personales para este usuario
      final existingData = await supabase
          .schema('jobs')
          .from('user_personal_data')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingData != null) {
        // Actualizar datos existentes
        await supabase
            .schema('jobs')
            .from('user_personal_data')
            .update(dataToInsert)
            .eq('user_id', userId);

        if (kDebugMode) {
          print('✅ Datos personales actualizados exitosamente');
        }
      } else {
        // Insertar nuevos datos
        await supabase
            .schema('jobs')
            .from('user_personal_data')
            .insert(dataToInsert);

        if (kDebugMode) {
          print('✅ Datos personales creados exitosamente');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al guardar datos personales: $e');
      }
      throw 'Error al guardar datos personales: ${e.toString()}';
    }
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await Supabase.instance.client
          .schema('jobs')
          .from('categories')
          .select('id, name')
          .order('name', ascending: true); // Ordenar alfabéticamente

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener todas las categorías: $e');
      }
      throw Exception('Error al cargar categorías: $e');
    }
  }

  /// Obtiene los datos personales del usuario
  Future<Map<String, dynamic>?> getPersonalData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'Usuario no autenticado';
      }

      final response = await supabase
          .schema('jobs')
          .from('user_personal_data_with_age')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (kDebugMode) {
        print('📊 Datos personales obtenidos: ${response != null ? 'Encontrados' : 'No encontrados'}');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener datos personales: $e');
      }
      return null;
    }
  }

  /// Valida si el usuario ha completado todos los datos personales requeridos
  Future<bool> hasCompletedPersonalData() async {
    try {
      final personalData = await getPersonalData();

      if (personalData == null) return false;

      // Verificar campos obligatorios
      final requiredFields = [
        'phone', 'birth_date', 'marital_status', 'gender',
        'city', 'country',
      ];

      for (final field in requiredFields) {
        if (personalData[field] == null ||
            personalData[field].toString().trim().isEmpty) {
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al verificar datos personales: $e');
      }
      return false;
    }
  }

  // Agregar un oficio específico a una categoría del usuario
  Future<void> addUserOficio(int categoryId, int oficioId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    try {
      // Verificar si ya existe
      final existing = await supabase
          .schema('jobs')
          .from('user_oficios')
          .select()
          .eq('user_id', user.id)
          .eq('category_id', categoryId)
          .eq('oficio_id', oficioId);

      if (existing.isNotEmpty) {
        throw Exception('Este oficio ya está en tu perfil');
      }

      // Verificar límite de oficios por categoría (máximo 3)
      final count = await supabase
          .schema('jobs')
          .from('user_oficios')
          .select()
          .eq('user_id', user.id)
          .eq('category_id', categoryId);

      if (count.length >= 3) {
        throw Exception('Solo puedes tener máximo 3 oficios por categoría');
      }

      // Insertar el nuevo oficio
      await supabase
          .schema('jobs')
          .from('user_oficios')
          .insert({
        'user_id': user.id,
        'category_id': categoryId,
        'oficio_id': oficioId,
      });
    } catch (e) {
      throw Exception('Error al agregar oficio: $e');
    }
  }

  // Eliminar un oficio específico del usuario
  Future<void> removeUserOficio(int categoryId, int oficioId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    try {
      await supabase
          .schema('jobs')
          .from('user_oficios')
          .delete()
          .eq('user_id', user.id)
          .eq('category_id', categoryId)
          .eq('oficio_id', oficioId);
    } catch (e) {
      throw Exception('Error al eliminar oficio: $e');
    }
  }

  // Obtener categorías y oficios del usuario
  Future<Map<String, dynamic>> getUserCategoriesWithOficios() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    try {
      // Obtener categorías
      final categoriesData = await supabase
          .schema('jobs')
          .from('user_categories')
          .select('category_id, categories:category_id(id, name)')
          .eq('user_id', user.id);

      final categories = <Map<String, dynamic>>[];
      final oficiosPorCategoria = <int, List<Map<String, dynamic>>>{};

      for (var item in categoriesData) {
        if (item['categories'] != null) {
          final category = item['categories'];
          categories.add(category);

          // Obtener oficios para esta categoría
          final oficiosData = await supabase
              .schema('jobs')
              .from('user_oficios')
              .select('oficio_id, oficios:oficio_id(id, name)')
              .eq('user_id', user.id)
              .eq('category_id', category['id']);

          final oficios = <Map<String, dynamic>>[];
          for (var oficioItem in oficiosData) {
            if (oficioItem['oficios'] != null) {
              oficios.add(oficioItem['oficios']);
            }
          }

          oficiosPorCategoria[category['id']] = oficios;
        }
      }

      return {
        'categories': categories,
        'oficiosPorCategoria': oficiosPorCategoria,
      };
    } catch (e) {
      throw Exception('Error al obtener categorías y oficios: $e');
    }
  }

  // Registro de usuario básico
  Future<AuthResponse> registerUser(String email, String password) async {
    if (kDebugMode) {
      print('UserService: Iniciando registro para: $email');
    }
    try {
      // Llamada directa como en la versión anterior que funcionaba
      return await supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) {
        print('UserService: Error durante el registro: $e');
      }
      rethrow;
    }
  }

  // Subir imagen de perfil
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final fileName = 'register/profile_${DateTime.now().millisecondsSinceEpoch}.png';
      final bytes = await imageFile.readAsBytes();

      // Subir la imagen
      await supabase.storage
          .from('profile_images')
          .uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      // Obtener URL pública
      final publicUrl = supabase.storage
          .from('profile_images')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Upload error: $e');
      }
      return null;
    }
  }

  // Cargar categorías disponibles
  Future<List<Map<String, dynamic>>> loadCategories() async {
    try {
      final response = await supabase
          .schema('jobs')
          .from('categories')
          .select('id, name')
          .order('name');

      return response.map((c) => {
        'id': c['id'] as int,
        'name': c['name'] as String,
        },
      ).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar categorías: $e');
      }
      return [];
    }
  }

  // Cargar habilidades disponibles
  Future<List<Map<String, dynamic>>> loadSkills() async {
    try {
      final response = await supabase
          .schema('jobs')
          .from('habilidades')
          .select('id, name')
          .limit(100);

      return response.map((s) => {
        'id': s['id'] as int,
        'name': s['name'] as String,
        },
      ).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar habilidades: $e');
      }
      return [];
    }
  }

  // Añadir habilidad al usuario
  Future<void> addUserSkill(int skillId, String nivel) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa');

    await supabase
        .schema('jobs')
        .from('habilidades_usuario')
        .insert({
      'habilidad_id': skillId,
      'user_id': user.id,
      'habilidades_id': skillId,
      'nivel': nivel,
    });
  }

  // Eliminar habilidad del usuario
  Future<void> removeUserSkill(int skillId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa');

    await supabase
        .schema('jobs')
        .from('habilidades_usuario')
        .delete()
        .eq('habilidad_id', skillId)
        .eq('user_id', user.id);
  }

  // Buscar habilidades
  Future<List<Map<String, dynamic>>> searchSkills(String query) async {
    try {
      final response = await supabase
          .schema('jobs')
          .from('habilidades')
          .select('id, name')
          .ilike('name', '%$query%')
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error al buscar habilidades: $e');
      }
      return [];
    }
  }

  // Crear nueva habilidad
  Future<Map<String, dynamic>?> createNewSkill(String skillName) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final result = await supabase
        .schema('jobs')
        .from('habilidades')
        .insert({
      'name': skillName,
      'user_id': user.id,
    })
        .select()
        .single();

    return result;
  }

  // Guardar categorías del usuario
  Future<void> saveUserCategories(List<Map<String, dynamic>> categories) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa');

    // Crear tabla si no existe
    try {
      await supabase.rpc('create_user_categories_table');
    } catch (e) {
      // La tabla puede ya existir, continuamos
    }

    // Insertar categorías
    for (var category in categories) {
      await supabase
          .schema('jobs')
          .from('user_categories')
          .insert({
        'user_id': user.id,
        'category_id': category['id'],
      });
    }
  }
}