import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

class WorkerAgendaScreen extends StatefulWidget {
  const WorkerAgendaScreen({super.key});

  @override
  State<WorkerAgendaScreen> createState() => _WorkerAgendaScreenState();
}

class _WorkerAgendaScreenState extends State<WorkerAgendaScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _agendas = [];

  @override
  void initState() {
    super.initState();
    _loadAgenda();
  }

  Future<void> _loadAgenda() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Buscar propuestas aceptadas y no completadas con fecha asignada
      final data = await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .select('id, amount, description, scheduled_date, receiver_id, room_id')
          .eq('sender_id', userId)
          .eq('status', 'accepted')
          .eq('is_completed', false)
          .not('scheduled_date', 'is', null)
          .gte('scheduled_date', DateTime.now().toUtc().toIso8601String()) // De hoy en adelante
          .order('scheduled_date', ascending: true);

      // Obtener nombres de los clientes
      List<Map<String, dynamic>> enrichedData = [];
      for (var item in data) {
        String clientName = 'Cliente Desconocido';
        try {
          final clientData = await _supabase
              .schema('chats')
              .from('users')
              .select('firstName, lastName')
              .eq('id', item['receiver_id'])
              .single();
          clientName = '${clientData['firstName'] ?? ''} ${clientData['lastName'] ?? ''}'.trim();
        } catch (e) {
          debugPrint('No se pudo cargar el cliente: $e');
        }

        enrichedData.add({
          ...item,
          'clientName': clientName,
          'dateObj': DateTime.parse(item['scheduled_date']).toLocal(),
        });
      }

      if (mounted) {
        setState(() {
          _agendas = enrichedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando agenda: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) { 
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageScheduledVisits),
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _agendas.isEmpty
              ? _buildEmptyState()
              : _buildAgendaList(),
    );
  }

  Widget _buildEmptyState() => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Agenda Despejada',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'No tienes visitas pendientes próximas.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );

  Widget _buildAgendaList() {
    // 1. Obtenemos el código de idioma actual (ej: 'es' o 'en')
    final String currentLocale = Localizations.localeOf(context).languageCode; // <--- CAMBIO 1

    // Usamos el locale para la moneda también, para que el formato de dinero sea correcto
    final moneyFormat = NumberFormat.currency(locale: currentLocale, symbol: '\$', decimalDigits: 0);
    
    String? lastDateHeader;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _agendas.length,
      itemBuilder: (context, index) {
        final item = _agendas[index];
        final DateTime date = item['dateObj'];
        
        // 2. Usamos un formato ESTÁNDAR (MMMMEEEEd) y le pasamos el idioma actual.
        // Esto generará automáticamente:
        // En Español: "sábado, 14 de febrero" (pone el 'de' solo)
        // En Inglés: "Saturday, February 14" (quita el 'de')
        final dateHeaderStr = DateFormat.MMMMEEEEd(currentLocale).format(date); // <--- CAMBIO 2
        
        // Nota: Si prefieres que siempre diga exactamente "Lunes 14 de Febrero" 
        // aunque sea en inglés, avísame, pero el formato de arriba es el nativo.

        // Comparar cabeceras
        bool showHeader = lastDateHeader != dateHeaderStr;
        lastDateHeader = dateHeaderStr;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                child: Text(
                  dateHeaderStr.toUpperCase(), // Esto lo pone en MAYÚSCULAS
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, letterSpacing: 1.2),
                ),
              ),
            ],
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Text(
                          // 3. También traducimos el formato de hora si es necesario (AM/PM vs 24h)
                          DateFormat.Hm(currentLocale).format(date), // <--- CAMBIO 3
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Icon(Icons.schedule, color: Colors.green.shade400, size: 16),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 60, color: Colors.grey.shade300),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['clientName'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['description'],
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              moneyFormat.format(item['amount']),
                              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}