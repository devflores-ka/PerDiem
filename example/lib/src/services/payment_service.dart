import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Genera un link de pago llamando a la Edge Function de Supabase
  Future<void> generarYAbrirPago({
    required String titulo,
    required double precio,
    required String receiverId, // ID del trabajador que recibe la plata
  }) async {
    try {
      if (kDebugMode) print('💸 Generando pago para: $titulo - \$$precio');

      // 1. Llamar a la Edge Function (Backend en Supabase)
      // Nota: Debes crear esta función en Supabase después
      final response = await _supabase.functions.invoke(
        'crear-preferencia-mp', // Nombre de tu función en Supabase
        body: {
          'title': titulo,
          'price': precio,
          'receiver_id': receiverId,
        },
      );

      final data = response.data;
      
      if (data != null && data['init_point'] != null) {
        final url = data['init_point'] as String;
        
        // 2. Abrir Mercado Pago (App o Web)
        if (kDebugMode) print('🔗 Abriendo link: $url');
        
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Importante para abrir la app de MP si está instalada
          );
        } else {
          throw 'No se pudo abrir el link de pago';
        }
      } else {
        throw 'Error al generar el link de pago';
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error pago: $e');
      rethrow;
    }
  }
}