import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '/l10n/generated/app_localizations.dart';

class MercadoPagoOnboardingScreen extends StatefulWidget {
  const MercadoPagoOnboardingScreen({super.key});

  @override
  State<MercadoPagoOnboardingScreen> createState() => _MercadoPagoOnboardingScreenState();
}

class _MercadoPagoOnboardingScreenState extends State<MercadoPagoOnboardingScreen> {
  bool _isLoading = false;

  Future<void> _iniciarVinculacion() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // 1. Buscamos dinámicamente la URL del backend en Supabase (nuestra ancla estática)
      final configData = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'backend_url')
          .single();

      final String baseUrl = configData['value'] as String;

      // 2. Con una URL fresca se le pide que arme el link de MP
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/payments/oauth/url?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // Tu API KEY
        },
      );

      // 3. Extraemos la URL de Mercado Pago del JSON
      final responseData = jsonDecode(response.body);
      final String authUrl = responseData['auth_url'];

      final uri = Uri.parse(authUrl);

      // 4. Abrimos el navegador
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        throw l10n.browserOpenError;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Un icono o logo para decorar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sync_alt, size: 80, color: Color(0xFF009EE3)),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.connectMercadoPago,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.connectMercadoPagoDesc,
              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const Spacer(),

            // Puntos de confianza
            _buildTrustItem(Icons.security, l10n.secureConnection),
            _buildTrustItem(Icons.flash_on, l10n.automaticTransfers),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _iniciarVinculacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009EE3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  l10n.connectWithMercadoPagoBtn,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Row(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      ],
    ),
  );
}
