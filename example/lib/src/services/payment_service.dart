import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  /// Genera un link de pago llamando al servidor en Go
  Future<void> generarYAbrirPago({
    required String titulo,
    required double precio,
    required String receiverId, // ID del trabajador que recibe la plata
    required String proposalId,
    required String payerId, // ID de quien paga
  }) async {

    try {
      if (kDebugMode) print('💸 Pidiendo link a Go para: $titulo - \$$precio');

      // 1. Buscamos dinámicamente la URL del backend en Supabase
      final configData = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'backend_url')
          .single();

      final String baseUrl = configData['value'] as String;
      final url = Uri.parse('$baseUrl/api/v1/payments/create');

      // 2. Enviar los datos con el Header de Autorización
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // Tu API KEY
        },
        body: jsonEncode({
          'proposal_id': proposalId,
          'payer_id': payerId,
          'receiver_id': receiverId,
          'amount': precio,
          'description': titulo,
        }),
      );

      // 3. Verificamos si Go nos dio luz verde (200 OK)
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Go nos devuelve 'checkout_url', lo extraemos
        if (data != null && data['checkout_url'] != null) {
          final checkoutUrl = data['checkout_url'] as String;

          if (kDebugMode) print('🔗 Intentando abrir link: $checkoutUrl');

          final uri = Uri.parse(checkoutUrl);

          try {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            throw 'Error al abrir el navegador: $e';
          }
        } else {
          throw 'Go no devolvió la URL de pago en el JSON.';
        }
      } else {
        throw 'Error del servidor Go: Código ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error pago: $e');
      rethrow;
    }
  }
}
