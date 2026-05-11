import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

class TrabajosScreen extends StatefulWidget {
  const TrabajosScreen({super.key});

  @override
  State<TrabajosScreen> createState() => _TrabajosScreenState();
}

class _TrabajosScreenState extends State<TrabajosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trabajos = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aquí sí es seguro llamar a AppLocalizations o Providers
    _cargarTrabajos(); 
  }

  Future<void> _cargarTrabajos() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtener trabajos donde soy el proveedor (sender_id)
      final trabajosComoProveedor = await supabase
          .schema('jobs')
          .from('budget_proposals')
          .select('id, description, completed_at, amount, room_id, receiver_id, sender_id')
          .eq('sender_id', user.id)
          .eq('is_completed', true)
          .order('completed_at', ascending: false);

      // Obtener trabajos donde soy el cliente (receiver_id)
      final trabajosComoCliente = await supabase
          .schema('jobs')
          .from('budget_proposals')
          .select('id, description, completed_at, amount, room_id, receiver_id, sender_id')
          .eq('receiver_id', user.id)
          .eq('is_completed', true)
          .order('completed_at', ascending: false);

      // Combinar ambos tipos de trabajos
      final todosLosTrabajos = <Map<String, dynamic>>[];

      // Procesar trabajos como proveedor
      for (var trabajo in trabajosComoProveedor) {
        try {
          // Obtener datos del cliente
          final clienteData = await supabase
              .schema('chats')
              .from('users')
              .select('firstName, lastName')
              .eq('id', trabajo['receiver_id'])
              .single();

          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'proveedor',
            'titulo': trabajo['description'] ?? 'Servicio prestado',
            'cliente_nombre': '${clienteData['firstName'] ?? ''} ${clienteData['lastName'] ?? ''}'.trim(),
            'mostrar_como': 'Servicio prestado a ${clienteData['firstName'] ?? 'Cliente'}',
          });
        } catch (e) {
          debugPrint('Error obteniendo datos del cliente: $e');
          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'proveedor',
            'titulo': trabajo['description'] ?? 'Servicio prestado',
            'cliente_nombre': 'Cliente',
            'mostrar_como': 'Servicio prestado',
          });
        }
      }

      // Procesar trabajos como cliente
      for (var trabajo in trabajosComoCliente) {
        try {
          // Obtener datos del proveedor
          final proveedorData = await supabase
              .schema('chats')
              .from('users')
              .select('firstName, lastName')
              .eq('id', trabajo['sender_id'])
              .single();

          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'cliente',
            'titulo': trabajo['description'] ?? l10n.serviceContracted,
            'proveedor_nombre': '${proveedorData['firstName'] ?? ''} ${proveedorData['lastName'] ?? ''}'.trim(),
            'mostrar_como': '${l10n.serviceOf} ${proveedorData['firstName'] ?? 'Proveedor'}',
          });
        } catch (e) {
          debugPrint('Error obteniendo datos del proveedor: $e');
          todosLosTrabajos.add({
            ...trabajo,
            'tipo': 'cliente',
            'titulo': trabajo['description'] ?? l10n.serviceContracted,
            'proveedor_nombre': 'Proveedor',
            'mostrar_como': l10n.serviceContracted,
          });
        }
      }

      // Ordenar todos los trabajos por fecha de finalización (más recientes primero)
      todosLosTrabajos.sort((a, b) {
        final fechaA = DateTime.parse(a['completed_at']);
        final fechaB = DateTime.parse(b['completed_at']);
        return fechaB.compareTo(fechaA);
      });

      setState(() {
        _trabajos = todosLosTrabajos; // ✅ Sin límite - todos los trabajos
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error al cargar trabajos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar trabajos: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
   final l10n = AppLocalizations.of(context)!;
   return Scaffold(
    appBar: AppBar(
      title: Text(l10n.myWorksTitle),
      foregroundColor: Colors.black,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _cargarTrabajos,
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _trabajos.isEmpty
        ? _buildEmptyState()
        : ListView.builder(
      itemCount: _trabajos.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final trabajo = _trabajos[index];
        return _buildTrabajoItem(trabajo);
      },
    ),
  );
  }

  Widget _buildEmptyState(){
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.work_off,
          size: 80,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.noJobsCompleted,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.allServicesContracted,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
  }

  Widget _buildTrabajoItem(Map<String, dynamic> trabajo) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    
    // Fecha automática: "February 14, 2024" (EN) o "14 de febrero de 2024" (ES)
    final dateFormat = DateFormat.yMMMMd(currentLocale);
    
    final moneyFormat = NumberFormat.currency(
      locale: currentLocale,
      symbol: '\$',
      decimalDigits: 0,
    );

    final fecha = trabajo['completed_at'] != null
        ? DateTime.parse(trabajo['completed_at'])
        : DateTime.now();

    final esProveedor = trabajo['tipo'] == 'proveedor';
    final titulo = trabajo['mostrar_como'] ?? trabajo['titulo'];
    final monto = trabajo['amount'] != null
        ? moneyFormat.format(trabajo['amount'])
        : '';

    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo de trabajo y fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: esProveedor ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        esProveedor ? Icons.build : Icons.shopping_cart,
                        color: esProveedor ? Colors.green.shade700 : Colors.blue.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        esProveedor ? 'Prestado' : l10n.contracted,
                        style: TextStyle(
                          color: esProveedor ? Colors.green.shade700 : Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dateFormat.format(fecha),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Título del trabajo
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),

            // Descripción si existe
            if (trabajo['description'] != null && trabajo['description'].toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  trabajo['description'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Información adicional y monto
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esProveedor ? 'Cliente:' : '${l10n.suplier}:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        esProveedor
                            ? (trabajo['cliente_nombre'] ?? 'Cliente')
                            : (trabajo['proveedor_nombre'] ?? 'Proveedor'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (monto.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      monto,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}