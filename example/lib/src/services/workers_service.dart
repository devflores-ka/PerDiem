// Archivo: lib/services/workers_service.dart
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkersService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene trabajadores cercanos usando la función de Supabase
  Future<List<Map<String, dynamic>>> getNearbyWorkers(
      LatLng position,
      String? categoryFilter,
      String? skillFilter,
      ) async {
    try {
      // ✅ OBTENER USUARIO ACTUAL PARA DEBUGGING
      final currentUser = _supabase.auth.currentUser;
      if (kDebugMode) {
        print('🔍 === WORKERS SERVICE DEBUG ===');
        print('👤 Usuario actual: ${currentUser?.id}');
        print('📍 Posición: ${position.latitude}, ${position.longitude}');
        print('📂 Categoría: ${categoryFilter ?? 'Todos'}');
        print('🔧 Oficio: ${skillFilter ?? 'Todas'}');
      }

      if (kDebugMode) {
        print('🔧 === CALLING RPC FUNCTION ===');
        print('🔧 Función: get_nearby_workers_fixed_security_grouped');
        print('🔧 Timestamp: ${DateTime.now().toIso8601String()}');
        print('🔧 Parámetros: {');
        print('  user_lat: ${position.latitude}');
        print('  user_lng: ${position.longitude}');
        print('  filter_category: ${categoryFilter ?? 'Todos'}');
        print('  filter_skill: ${skillFilter ?? 'Todas'}');
        print('  max_distance_km: 50.0');
        print('}');
      }

      // Llamar a la función agrupada que evita duplicados
      dynamic response;
      try {
        response = await _supabase.rpc(
          'get_nearby_workers_fixed_security_grouped',
          params: {
            'user_lat': position.latitude,
            'user_lng': position.longitude,
            'filter_category': categoryFilter ?? 'Todos',
            'filter_skill': skillFilter ?? 'Todas',
            'max_distance_km': 50.0,
          },
        );
        if (kDebugMode) {
          print('✅ Método agrupado exitoso');
        }
      } catch (e1) {
        if (kDebugMode) {
          print('❌ Función agrupada no existe, usando función original: $e1');
        }

        // Fallback a la función original
        response = await _supabase.rpc(
          'get_nearby_workers_fixed_security',
          params: {
            'user_lat': position.latitude,
            'user_lng': position.longitude,
            'filter_category': categoryFilter ?? 'Todos',
            'filter_skill': skillFilter ?? 'Todas',
            'max_distance_km': 50.0,
          },
        );
        if (kDebugMode) {
          print('✅ Función original exitosa');
        }
      }

      if (kDebugMode) {
        print('🎯 === RPC RESPONSE ===');
        print('📡 Tipo de respuesta: ${response.runtimeType}');
        print('📡 Es lista: ${response is List}');
        if (response is List) {
          print('📡 Trabajadores encontrados RAW: ${response.length}');
          print('📡 IDs únicos encontrados: ${response.map((w) => w['user_id']).toSet().toList()}');

          // Mostrar TODOS los trabajadores, no solo el primero
          for (var i = 0; i < response.length; i++) {
            final worker = response[i];
            final isCurrentUser = worker['user_id'] == currentUser?.id;
            print('📡 [$i] ${worker['firstname']} ${worker['lastname']} (${worker['user_id'].toString().substring(0, 8)}...) - ${worker['category_name']} ${isCurrentUser ? '👤 (TU)' : ''}');
          }
        }
      }

      if (response is! List) {
        if (kDebugMode) {
          print('⚠️ Respuesta no es una lista, devolviendo lista vacía');
        }
        return <Map<String, dynamic>>[];
      }

      // ✅ IMPORTANTE: NO FILTRAR POR USUARIO ACTUAL - MOSTRAR TODOS
      final workers = _transformAndGroupWorkerData(response);

      if (kDebugMode) {
        print('✅ Trabajadores transformados: ${workers.length}');
        print('📊 VERIFICACIÓN FINAL:');
        for (var i = 0; i < workers.length; i++) {
          final worker = workers[i];
          final user = worker['user'] as Map<String, dynamic>;
          final isCurrentUser = user['id'] == currentUser?.id;
          print('  [$i] ${user['firstName']} ${user['lastName']} - ${worker['categories']} ${isCurrentUser ? '👤 (TU)' : ''}');
        }
      }

      return workers;

    } on PostgrestException catch (e) {
      if (kDebugMode) {
        print('❌ Error PostgreSQL: ${e.message}');
        print('❌ Detalles: ${e.details}');
        print('❌ Código: ${e.code}');
      }
      return <Map<String, dynamic>>[];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error general obteniendo trabajadores: $e');
        print('❌ Stack trace: $stackTrace');
      }
      return <Map<String, dynamic>>[];
    }
  }

  /// ✅ FUNCIÓN CORREGIDA: Transforma TODOS los trabajadores sin filtrar por usuario actual
  List<Map<String, dynamic>> _transformAndGroupWorkerData(List<dynamic> rawData) {
    final workersMap = <String, Map<String, dynamic>>{};
    final currentUserId = _supabase.auth.currentUser?.id;

    for (var i = 0; i < rawData.length; i++) {
      try {
        final worker = rawData[i] as Map<String, dynamic>;
        final userId = worker['user_id']?.toString() ?? '';

        if (userId.isEmpty) continue;

        // ✅ CRÍTICO: NO EXCLUIR USUARIOS - MOSTRAR TODOS
        // Comentamos esta línea que podría estar filtrando:
        // if (userId == currentUserId) continue; // ❌ NO HACER ESTO

        // Si ya existe el trabajador, agregar categorías
        if (workersMap.containsKey(userId)) {
          final existingWorker = workersMap[userId]!;
          final existingCategoriesStr = existingWorker['categories'] as String;
          final newCategory = worker['category_name']?.toString() ?? '';

          // Agregar nueva categoría si no existe
          if (newCategory.isNotEmpty && !existingCategoriesStr.contains(newCategory)) {
            existingWorker['categories'] = '$existingCategoriesStr, $newCategory';
          }
        } else {
          // ✅ MAPEO CORRECTO: Usar campos en minúsculas que vienen de SQL
          final transformedWorker = {
            'user': {
              'id': userId,
              'firstName': worker['firstname']?.toString() ?? 'Sin nombre',
              'lastName': worker['lastname']?.toString() ?? '',
              'imageUrl': worker['imageurl']?.toString() ?? _getDefaultAvatarUrl(),
              'rating': _parseDouble(worker['avg_rating']),
              'rating_count': _parseInt(worker['rating_count']),
              'descripcion': worker['descripcion']?.toString() ?? '',
            },
            'latitud': _parseDouble(worker['latitud']),
            'longitud': _parseDouble(worker['longitud']),
            'categories': worker['category_name']?.toString() ?? 'Sin categoría',
            'category': worker['category_name']?.toString() ?? 'Sin categoría',
            'skill': worker['oficio_name']?.toString() ?? 'Sin oficio específico',
            'distance_km': _parseDouble(worker['distance_km']),
            'is_current_user': userId == currentUserId, // ✅ Solo para información
          };

          workersMap[userId] = transformedWorker;
        }

        // Debug mejorado
        if (kDebugMode && i < 3) { // Mostrar solo los primeros 3 para no saturar logs
          final isCurrentUser = userId == currentUserId;
          if (kDebugMode) {
            print('🔄 [$i] Transformando: ${worker['firstname']} ${worker['lastname']} ${isCurrentUser ? '👤 (TU)' : ''}');
          }
        }

      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error transformando trabajador $i: $e');
          print('⚠️ Datos del trabajador: ${rawData[i]}');
        }
        continue;
      }
    }

    final result = workersMap.values.toList();

    if (kDebugMode) {
      print('📊 RESULTADO FINAL DE TRANSFORMACIÓN:');
      print('   - Total trabajadores: ${result.length}');
      print('   - IDs únicos: ${result.map((w) => (w['user'] as Map)['id']).toList()}');

      // Verificar si incluye otros usuarios además del actual
      final currentUserIncluded = result.any((w) => (w['user'] as Map)['id'] == currentUserId);
      final othersIncluded = result.any((w) => (w['user'] as Map)['id'] != currentUserId);

      print('   - Incluye usuario actual: $currentUserIncluded');
      print('   - Incluye otros usuarios: $othersIncluded');

      if (!othersIncluded && result.isNotEmpty) {
        print('⚠️ PROBLEMA: Solo se está mostrando el usuario actual!');
      }
    }

    return result;
  }

  String _getDefaultAvatarUrl() {
    // Usar servicio que genera avatares dinámicos
    return 'https://ui-avatars.com/api/?name=Usuario&background=0D8ABC&color=fff&size=128&rounded=true';
  }

  /// Métodos auxiliares para parsing seguro
  double _parseDouble(dynamic value) {
    try {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error parseando double: $value -> $e');
      }
      return 0.0;
    }
  }

  int _parseInt(dynamic value) {
    try {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error parseando int: $value -> $e');
      }
      return 0;
    }
  }

  /// ✅ NUEVO: Método para debugging específico - verificar qué está filtrando
  Future<void> debugWorkerFiltering(LatLng position) async {
    try {
      if (kDebugMode) {
        print('🐛 === DEBUG: VERIFICANDO FILTRADO DE TRABAJADORES ===');
      }

      // Llamar directamente a la función SQL
      final response = await _supabase.rpc(
        'get_nearby_workers_fixed_security_grouped',
        params: {
          'user_lat': position.latitude,
          'user_lng': position.longitude,
          'filter_category': 'Todos',
          'filter_skill': 'Todas',
          'max_distance_km': 50.0,
        },
      );

      if (response is List) {
        if (kDebugMode) {
          print('🐛 Respuesta directa de SQL: ${response.length} trabajadores');

          for (var i = 0; i < response.length; i++) {
            final worker = response[i];
            print('🐛 [$i] ${worker['firstname']} ${worker['lastname']} (${worker['user_id']})');
          }

          // Verificar si hay algún filtro oculto en el proceso
          final transformed = _transformAndGroupWorkerData(response);
          print('🐛 Después de transformación: ${transformed.length} trabajadores');

          if (response.length != transformed.length) {
            print('❌ PROBLEMA: Se están perdiendo trabajadores en la transformación!');
            print('   Original: ${response.length} -> Transformado: ${transformed.length}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en debug: $e');
      }
    }
  }

  /// Método para debugging - obtener trabajadores sin filtros
  Future<List<Map<String, dynamic>>> getAllWorkersForDebugging() async {
    try {
      if (kDebugMode) {
        print('🐛 DEBUG: Obteniendo TODOS los trabajadores sin filtros');
      }

      final response = await _supabase.rpc(
        'get_nearby_workers_fixed_security_grouped',
        params: {
          'user_lat': 30.421309,
          'user_lng': -87.2169149,
          'filter_category': 'Todos',
          'filter_skill': 'Todas',
          'max_distance_km': 1000.0,
        },
      );

      if (kDebugMode) {
        print('🐛 DEBUG: Respuesta tipo: ${response.runtimeType}');
        if (response is List) {
          print('🐛 DEBUG: ${response.length} trabajadores encontrados en total');
        }
      }

      if (response is! List) {
        return <Map<String, dynamic>>[];
      }

      return _transformAndGroupWorkerData(response);

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ DEBUG: Error obteniendo todos los trabajadores: $e');
        print('❌ DEBUG: Stack trace: $stackTrace');
      }
      return <Map<String, dynamic>>[];
    }
  }

  /// Método de prueba para verificar conexión con Supabase
  Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        print('🔗 Probando conexión con Supabase...');
      }

      final response = await _supabase
          .schema('jobs')
          .from('categories')
          .select('id')
          .limit(1);

      if (kDebugMode) {
        print('✅ Conexión con Supabase exitosa: $response');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error de conexión con Supabase: $e');
      }
      return false;
    }
  }
}