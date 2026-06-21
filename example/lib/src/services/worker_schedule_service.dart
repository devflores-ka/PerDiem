import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerScheduleService {
  static final _supabase = Supabase.instance.client;

  // Verificar si un trabajador está disponible en una fecha específica
  static Future<bool> checkAvailability(String workerId, DateTime fullDate) async { // Cambié nombre a fullDate para ser explícito
    try {
      final params = {
        'target_worker_id': workerId,
        'target_datetime': fullDate.toIso8601String(), // Enviamos la hora completa
      };

      // Llamada a la función RPC actualizada
      final isAvailable = await _supabase
          .schema('jobs')
          .rpc('check_worker_availability', params: params);
      return isAvailable as bool;
    } catch (e) {
      if (kDebugMode) {
        print('Error verificando disponibilidad: $e');
      }
      return true; 
    }
  }

  // Configurar un día de trabajo (Para el perfil del trabajador)
  static Future<void> setWorkDay(int dayOfWeek, String startTime, String endTime) async {
    final userId = _supabase.auth.currentUser!.id;
    
    await _supabase.schema('jobs').from('worker_schedules').upsert({
      'user_id': userId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_active': true,
    }, onConflict: 'user_id, day_of_week',);
  }
  
  // Obtener los días que trabaja (para mostrar en calendario visualmente)
  static Future<List<int>> getWorkingDays(String workerId) async {
    final response = await _supabase
        .from('worker_schedules')
        .select('day_of_week')
        .eq('user_id', workerId)
        .eq('is_active', true);
        
    return (response as List).map((e) => e['day_of_week'] as int).toList();
  }
}