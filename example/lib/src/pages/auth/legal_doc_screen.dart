import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalDocScreen extends StatelessWidget {
  final String docType; // 'terms' o 'privacy'

  const LegalDocScreen({
    super.key, 
    this.docType = 'terms',
  });

  Future<Map<String, dynamic>> _fetchDocument() async {
    try {
      final response = await Supabase.instance.client
          .from('app_legal_docs')
          .select('title, content, version')
          .eq('type', docType)
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Error cargando documento: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(docType == 'terms' ? 'Términos y Condiciones' : 'Política de Privacidad'),
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchDocument(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo cargar el documento legal.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => (context as Element).markNeedsBuild(),
                      child: const Text('Reintentar'),
                    )
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final title = data['title'] ?? 'Documento Legal';
          final content = data['content'] ?? 'Sin contenido disponible.';
          final version = data['version'] ?? '1.0';

          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versión $version', 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Divider(height: 30),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 15, 
                      height: 1.5, 
                      color: Colors.black87
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Botón "Entendido"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
}