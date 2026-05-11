import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchService {
  final supabase = Supabase.instance.client;

  /// Guarda un registro de búsqueda en la base de datos
  Future<void> logSearch({
    required String query,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      
      // Solo guardamos si hay algo escrito o filtros aplicados
      if (query.isEmpty && (filters == null || filters.isEmpty)) return;

      await supabase.schema('jobs').from('search_logs').insert({
        'user_id': user?.id, // Puede ser null si no está logueado
        'query': query.trim(),
        'filters': filters ?? {},
      });
      
      if (kDebugMode) {
        print('🔍 Búsqueda guardada: "$query" - Filtros: $filters');
      }
    } catch (e) {
      // Fallar en silencio para no molestar al usuario, pero loguear en consola
      if (kDebugMode) print('⚠️ Error guardando log de búsqueda: $e');
    }
  }
}