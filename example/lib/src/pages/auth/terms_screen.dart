import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  Future<String> _fetchTerms() async {
    try {
      final response = await Supabase.instance.client
          .from('app_legal_docs')
          .select('content')
          .eq('type', 'terms')
          .single();
      
      return response['content'] as String;
    } catch (e) {
      return 'No se pudieron cargar los términos y condiciones. Por favor verifica tu conexión.';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<String>(
        future: _fetchTerms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final content = snapshot.data ?? 'No hay información disponible.';

          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Términos de Uso',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Última actualización: Hoy', // Podrías traer la fecha de la DB también
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 40),
                  // Botón grande para cerrar, útil para UX
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ENTENDIDO'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
}