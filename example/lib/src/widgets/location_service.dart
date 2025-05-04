import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkersService {
  // Singleton pattern
  static final WorkersService _instance = WorkersService._internal();
  factory WorkersService() => _instance;
  WorkersService._internal();

  final double distanceLimitKm = 5.0;

  /// Obtiene trabajadores cercanos mediante RPC
  // Código corregido para WorkersService.getNearbyWorkers

  Future<List<Map<String, dynamic>>> getNearbyWorkers(
      LatLng position,
      String? category,
      ) async {
    try {
      if (kDebugMode) {
        print('Recuperando trabajadores cercanos con RPC...');
        print('Latitud: ${position.latitude}, Longitud: ${position.longitude}');
        if (category != null && category != 'Todos') {
          print('Filtrando por categoría: $category');
        }
      }

      // Agregar más logs para depuración
      final response = await Supabase.instance.client
          .schema('jobs')
          .rpc('get_nearby_workers_by_category', params: {
        'user_lat': position.latitude,
        'user_lng': position.longitude,
        'max_distance_km': distanceLimitKm,
        'category_name': category ?? 'Todos',
        },
      );

      // Log de la respuesta cruda para entender su estructura
      if (kDebugMode) {
        print('Respuesta RPC sin procesar: $response');
        print('Tipo de respuesta: ${response.runtimeType}');
      }

      // Problema: Para PostgreSQL RPCs que devuelven TABLE, Supabase ya devuelve una Lista
      // y no necesita casting adicional
      final locationData = response as List;

      if (locationData.isEmpty) {
        if (kDebugMode) print('No se encontraron trabajadores cercanos.');
        return [];
      }

      // Convertir cada elemento a Map si no lo son ya
      final typedLocationData = locationData.map((item) =>
      item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map),
      ).toList();

      final userIds = typedLocationData.map((e) => e['user_id'] as String).toList();

      if (kDebugMode) {
        print('ID de trabajador encontrado: $userIds');
      }

      final userData = await Supabase.instance.client
          .schema('chats')
          .from('users')
          .select('id, firstName, lastName, imageUrl, role')
          .inFilter('id', userIds);

      if (kDebugMode) {
        print('Datos de usuario obtenidos: ${userData.length}');
      }

      final usersById = {
        for (var user in userData) user['id']: user,
      };

      final enrichedWorkers = typedLocationData.map((worker) {
        final user = usersById[worker['user_id']];
        return {
          ...worker,
          'user': user,
        };
      }).toList();

      if (kDebugMode) {
        print('Los trabajadores encontraron: ${enrichedWorkers.length}');
        for (final worker in enrichedWorkers) {
          print('Trabajador: $worker');
        }
      }

      return enrichedWorkers;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener trabajadores a través de RPC: $e');
      }
      return [];
    }
  }

  /// Actualiza ubicación del trabajador
  Future<bool> updateWorkerLocation(
      String userId,
      LatLng position,
      String category,
      ) async {
    try {
      await Supabase.instance.client
          .schema('jobs')
          .from('worker_locations')
          .upsert({
        'user_id': userId,
        'latitud': position.latitude,
        'longitud': position.longitude,
        'user_type': 'worker',
        'category': category,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating worker location: $e');
      }
      return false;
    }
  }
}
