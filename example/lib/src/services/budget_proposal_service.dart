import 'dart:async'; // Necesario para el Timer del botón deshacer
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:intl/intl.dart';
import 'package:perdiem_app/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ignore: unused_import
import '../widgets/mercado_pago_button.dart';
import 'worker_schedule_service.dart';

class BudgetProposal {
  final String id;
  final String roomId;
  final String senderId;
  final String receiverId;
  final double amount;
  final String description;
  final String status; // pending, accepted, rejected, countered
  final String? counterProposalId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? scheduledDate; // Fecha OFICIAL (Ya aceptada)
  final DateTime? proposedDate;  // Fecha PROPUESTA (Pendiente de aceptación)
  final bool isCompleted; 
  final DateTime? completedAt;
  final String? paymentMethod;

  BudgetProposal({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.description,
    required this.status,
    this.counterProposalId,
    required this.createdAt,
    required this.updatedAt,
    this.scheduledDate,
    this.proposedDate,
    this.isCompleted = false,
    this.completedAt,
    this.paymentMethod,
  });

  factory BudgetProposal.fromJson(Map<String, dynamic> json) => BudgetProposal(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      amount: json['amount'] is int ? (json['amount'] as int).toDouble() : json['amount'],
      description: json['description'] ?? '',
      status: json['status'],
      counterProposalId: json['counter_proposal_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      
      // Manejo de fechas
      scheduledDate: json['scheduled_date'] != null ? DateTime.parse(json['scheduled_date']) : null,
      proposedDate: json['proposed_date'] != null ? DateTime.parse(json['proposed_date']) : null,
      
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
  
      paymentMethod: json['payment_method'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'amount': amount,
      'description': description,
      'status': status,
      'counter_proposal_id': counterProposalId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'scheduled_date': scheduledDate?.toIso8601String(),
      'proposed_date': proposedDate?.toIso8601String(),
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'payment_method': paymentMethod,
    };
}

class BudgetProposalService {
  static final _supabase = Supabase.instance.client;

  // --- MÉTODOS DE CREACIÓN Y GESTIÓN BÁSICA ---

  static Future<BudgetProposal> createProposal({
    required String roomId,
    required String receiverId,
    required double amount,
    required String description,
  }) async {
    final currentUserId = _supabase.auth.currentUser!.id;
    final response = await _supabase.schema('jobs').from('budget_proposals').insert({
      'room_id': roomId,
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'amount': amount,
      'description': description,
      'status': 'pending',
    }).select().single();
    return BudgetProposal.fromJson(response);
  }

  static Future<void> updatePaymentMethod(String proposalId, String? method) async {
    try {
      await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .update({'payment_method': method}) // Guarda 'cash', 'digital' o null
          .eq('id', proposalId);
    } catch (e) {
      debugPrint('Error guardando método de pago: $e');
    }
  }

  // Verifica si el servicio está completado y listo para recibir reseñas
  static Future<bool> isServiceReadyForReview(String proposalId) async {
    try {
      final response = await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .select()
          .eq('id', proposalId)
          .single();

      final proposal = BudgetProposal.fromJson(response);
      return proposal.isCompleted;
    } catch (e) {
      debugPrint('Error al verificar si el servicio está listo para reseñas: $e');
      return false;
    }
  }

  static Future<BudgetProposal> createCounterProposal({
    required String originalProposalId,
    required String roomId,
    required String receiverId,
    required double amount,
    required String description,
  }) async {
    final currentUserId = _supabase.auth.currentUser!.id;
    await _supabase.schema('jobs').from('budget_proposals').update({'status': 'countered'}).eq('id', originalProposalId);
    final response = await _supabase.schema('jobs').from('budget_proposals').insert({
      'room_id': roomId,
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'amount': amount,
      'description': description,
      'status': 'pending',
      'counter_proposal_id': originalProposalId,
    }).select().single();
    return BudgetProposal.fromJson(response);
  }

  static Future<void> acceptProposal(String proposalId) async {
    await _supabase.schema('jobs').from('budget_proposals').update({'status': 'accepted'}).eq('id', proposalId);
  }

  static Future<void> rejectProposal(String proposalId) async {
    await _supabase.schema('jobs').from('budget_proposals').update({'status': 'rejected'}).eq('id', proposalId);
  }

  // --- MÉTODOS DE CONSULTA Y STREAM ---

  static Stream<List<BudgetProposal>> getProposalsStream(String roomId) {
    return _supabase.schema('jobs').from('budget_proposals').stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((data) => data.map((item) => BudgetProposal.fromJson(item)).toList());
  }

  static Future<BudgetProposal?> getProposalById(String proposalId) async {
    try {
      final response = await _supabase.schema('jobs').from('budget_proposals').select().eq('id', proposalId).single();
      return BudgetProposal.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // --- MÉTODOS DE AGENDAMIENTO (NUEVO FLUJO) ---

  // 1. Trabajador PROPONE una fecha (No la fija todavía)
  static Future<void> proposeServiceDate(String proposalId, DateTime date) async {
    await _supabase.schema('jobs').from('budget_proposals').update({
      'proposed_date': date.toIso8601String(),
    }).eq('id', proposalId);
  }

  // 2. Cliente ACEPTA la fecha (Se mueve de proposed a scheduled)
  static Future<void> acceptServiceDate(String proposalId, DateTime date) async {
    await _supabase.schema('jobs').from('budget_proposals').update({
      'scheduled_date': date.toIso8601String(),
      'proposed_date': null, // Limpiamos la propuesta
    }).eq('id', proposalId);
  }

  // 3. Cliente RECHAZA la fecha (Se limpia proposed)
  static Future<void> rejectServiceDate(String proposalId) async {
    await _supabase.schema('jobs').from('budget_proposals').update({
      'proposed_date': null,
    }).eq('id', proposalId);
  }

  // --- OTROS MÉTODOS ---
  static Future<void> markServiceAsCompleted(String proposalId) async {
    await _supabase.schema('jobs').from('budget_proposals').update({
      'is_completed': true,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', proposalId);
  }

  static Future<String?> getUserRoleInProposal(String proposalId) async {
    final currentUserId = _supabase.auth.currentUser!.id;
    try {
      final response = await _supabase.schema('jobs').from('budget_proposals').select().eq('id', proposalId).single();
      final proposal = BudgetProposal.fromJson(response);
      if (proposal.senderId == currentUserId) return 'provider';
      if (proposal.receiverId == currentUserId) return 'client';
      return null;
    } catch (e) { return null; }
  }
}

// ---------------------------------------------------------------------------
//                                 WIDGETS
// ---------------------------------------------------------------------------

class BudgetProposalMessage extends StatefulWidget {
  final BudgetProposal proposal;
  final types.User currentUser;
  final bool amITheWorker;
  final Function(BudgetProposal) onAccept;
  final Function(BudgetProposal) onReject;
  final Function(BudgetProposal) onCounter;

  const BudgetProposalMessage({
    super.key,
    required this.proposal,
    required this.currentUser,
    required this.amITheWorker,
    required this.onAccept,
    required this.onReject,
    required this.onCounter,
  });

  @override
  State<BudgetProposalMessage> createState() => _BudgetProposalMessageState();
}

class _BudgetProposalMessageState extends State<BudgetProposalMessage> {
  // Estado para el contador de deshacer
  bool _canUndo = false;
  int _undoSeconds = 10;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    // Iniciamos el timer SOLO si acaba de ser aceptada y NO hemos avanzado
    if (widget.proposal.status == 'accepted' && 
        widget.proposal.paymentMethod == null &&
        widget.proposal.proposedDate == null &&
        widget.proposal.scheduledDate == null) {
      final diff = DateTime.now().difference(widget.proposal.updatedAt.toLocal()).inSeconds;
      if (diff < 10) {
        _startUndoTimer(10 - diff);
      }
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _startUndoTimer(int seconds) {
    setState(() {
      _canUndo = true;
      _undoSeconds = seconds;
    });
    _undoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _undoSeconds--;
      });
      if (_undoSeconds <= 0) {
        timer.cancel();
        setState(() {
          _canUndo = false;
        });
      }
    });
  }

  // Lógica para elegir fecha (Solo Worker)
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final baseDate = widget.proposal.scheduledDate ?? widget.proposal.proposedDate ?? now.add(const Duration(days: 1));
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: baseDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
      helpText: 'SELECCIONAR DÍA',
    );

    if (pickedDate == null) return; // Si cancela la fecha, salimos

    if (!mounted) return;

    // 2. SELECCIONAR HORA (¡NUEVO!)
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseDate), // Usar hora actual o guardada
      helpText: 'SELECCIONAR HORA DE INICIO',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return; // Si cancela la hora, salimos

    // 3. COMBINAR FECHA + HORA
    final DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // 4. VALIDAR DISPONIBILIDAD EXACTA
    // Ahora enviamos la fecha con hora exacta para ver si choca con otro bloque
    final isAvailable = await WorkerScheduleService.checkAvailability(widget.proposal.senderId, finalDateTime);
    
    if (!isAvailable) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Horario no disponible (Ya tienes un trabajo a esa hora o está fuera de tu jornada).'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return; 
    }

    // 5. GUARDAR SI TODO ESTÁ OK
    try {
      await BudgetProposalService.proposeServiceDate(widget.proposal.id, finalDateTime);
      
      // Formato bonito: "lunes 23 de febrero a las 14:30"
      final dateStr = DateFormat("EEEE d 'de' MMMM 'a las' HH:mm", 'es_ES').format(finalDateTime);
      final message = types.PartialText(text: '📅 He propuesto una nueva fecha: $dateStr. ¿Te acomoda?');
      await SupabaseChatCore.instance.sendMessage(message, widget.proposal.roomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Propuesta de horario enviada')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // Lógica para aceptar fecha (Solo Cliente)
  Future<void> _acceptDate(BuildContext context) async {
    if (widget.proposal.proposedDate == null) return;
    try {
      await BudgetProposalService.acceptServiceDate(widget.proposal.id, widget.proposal.proposedDate!);
      
      final dateStr = DateFormat('dd/MM/yyyy', 'es_ES').format(widget.proposal.proposedDate!);
      final message = types.PartialText(text: '✅ Fecha aceptada. Nos vemos el $dateStr');
      await SupabaseChatCore.instance.sendMessage(message, widget.proposal.roomId);

      final completionMessage = types.PartialCustom(
        metadata: {
          'type': 'service_completion',
          'proposal_id': widget.proposal.id,
        },
      );
      await SupabaseChatCore.instance.sendMessage(completionMessage, widget.proposal.roomId);

    } catch (e) { debugPrint('Error: $e'); }
  }

  // Lógica para rechazar fecha (Solo Cliente)
  Future<void> _rejectDate(BuildContext context) async {
    try {
      await BudgetProposalService.rejectServiceDate(widget.proposal.id);
      final message = types.PartialText(text: '⚠️ La fecha propuesta no me acomoda. Por favor propón otra.');
      await SupabaseChatCore.instance.sendMessage(message, widget.proposal.roomId);
    } catch (e) { debugPrint('Error: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    final isMyProposal = proposal.senderId == widget.currentUser.id;
    final numberFormat = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    
    // Determinar quién es el "otro" para pagos
    final otherUserId = proposal.senderId == widget.currentUser.id ? proposal.receiverId : proposal.senderId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMyProposal ? Colors.blue[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMyProposal ? Colors.blue[300]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // CABECERA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Presupuesto ${isMyProposal ? 'Enviado' : 'Recibido'}',
                style: TextStyle(fontWeight: FontWeight.bold, color: isMyProposal ? Colors.blue[700] : Colors.grey[800]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _getStatusColor(proposal.status), borderRadius: BorderRadius.circular(12)),
                child: Text(_getStatusText(proposal.status), style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(numberFormat.format(proposal.amount), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          
          if (proposal.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(proposal.description),
          ],
          
          // --- MOSTRAR FECHAS (Solo si NO está rechazado) ---
          if (proposal.status != 'rejected') ...[
            // CASO A: Fecha YA Agendada (Oficial)
            if (proposal.scheduledDate != null) ...[
              const SizedBox(height: 12),
              _buildDateInfo(proposal.scheduledDate!, 'Visita Agendada', Colors.green, Icons.check_circle),
            ]
            // CASO B: Fecha Propuesta (Pendiente)
            else if (proposal.proposedDate != null) ...[
              const SizedBox(height: 12),
              _buildDateInfo(proposal.proposedDate!, 'Fecha Propuesta', Colors.orange, Icons.access_time_filled),
            ],
          ],

          // --- ACCIONES PRINCIPALES ---

          // CASO ESPECIAL: RECHAZADO (Corrección del Overflow)
          if (proposal.status == 'rejected')
             Container(
               width: double.infinity,
               margin: const EdgeInsets.only(top: 16),
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
               child: const Row(
                 children: [
                   Icon(Icons.cancel, color: Colors.red),
                   SizedBox(width: 8),
                   // EL FIX: Usamos Expanded para que el texto no se salga de la pantalla
                   Expanded(
                     child: Text(
                       'Esta propuesta ha sido cerrada.', 
                       style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                       overflow: TextOverflow.visible,
                     ),
                   ),
                 ],
               ),
             )
          else ...[
             // 1. NEGOCIACIÓN PRECIO
             if (proposal.status == 'pending' && !isMyProposal) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton(onPressed: () => widget.onAccept(proposal), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('Aceptar')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => widget.onReject(proposal), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Rechazar')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => widget.onCounter(proposal), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), child: const Text('Contraofertar')),
                    ],
                  ),
                ),
             ],

             // 2. FASE ACEPTADA (Agendamiento y Pagos)
             if (proposal.status == 'accepted') 
                _buildAcceptedActions(context, otherUserId),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedActions(BuildContext context, String otherUserId) => Column(
      children: [
        // A. Botón Deshacer (Ahora no oculta el resto de la interfaz)
        if (_canUndo)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                _undoTimer?.cancel();
                try {
                  await Supabase.instance.client.schema('jobs').from('budget_proposals')
                      .update({'status': 'pending'}).eq('id', widget.proposal.id);
                } catch (e) { debugPrint('Error deshacer: $e'); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
              icon: const Icon(Icons.undo),
              label: Text('Deshacer aceptación ($_undoSeconds s)'),
            ),
          ),

        // B. Flujo de Agendamiento
        // SI SOY TRABAJADOR
        if (widget.amITheWorker) ...[
          if (widget.proposal.scheduledDate == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_month),
                label: Text(widget.proposal.proposedDate == null ? 'Proponer Fecha' : 'Cambiar Propuesta'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
              ),
            ),
          if (widget.proposal.proposedDate != null && widget.proposal.scheduledDate == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Esperando confirmación del cliente...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ),
        ],

        // SI SOY CLIENTE (Y no soy trabajador)
        if (!widget.amITheWorker) ...[
          // Si hay una propuesta de fecha pendiente, me toca aceptar/rechazar
          if (widget.proposal.proposedDate != null && widget.proposal.scheduledDate == null) 
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptDate(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Aceptar Fecha'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectDate(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100], foregroundColor: Colors.red),
                    child: const Text('Cambiar'),
                  ),
                ),
              ],
            )
          else if (widget.proposal.scheduledDate == null)
             const Text('Esperando que el trabajador proponga fecha...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
             
          const SizedBox(height: 12),
          // Selector de Pago (Siempre visible para el cliente)
          PaymentMethodSelector(
            proposal: widget.proposal,
            amount: widget.proposal.amount,
            description: widget.proposal.description,
            targetWorkerId: otherUserId,
          ),
        ],
      ],
    );
  
  Widget _buildDateInfo(DateTime date, String label, Color color, IconData icon) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                Text(
                  DateFormat("EEEE d 'de' MMMM, HH:mm", 'es_ES').format(date),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      case 'countered': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pendiente';
      case 'accepted': return 'Aceptado';
      case 'rejected': return 'Rechazado';
      case 'countered': return 'Contraofertado';
      default: return 'Desconocido';
    }
  }
}

// Widget de pago
class PaymentMethodSelector extends StatefulWidget {
  final BudgetProposal proposal; // <--- AÑADIDO
  final double amount;
  final String description;
  final String targetWorkerId;

  const PaymentMethodSelector({
    super.key, 
    required this.proposal, // <--- AÑADIDO
    required this.amount, 
    required this.description, 
    required this.targetWorkerId,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  String? _selectedMethod;

  // --- PASO 4.1: Cargar el dato al inicio ---
  @override
  void initState() {
    super.initState();
    // Leer el método de pago que viene de la base de datos
    _selectedMethod = widget.proposal.paymentMethod; 
  }

  @override
  void didUpdateWidget(PaymentMethodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Escucha la actualización de la BD en tiempo real y refresca el botón
    if (widget.proposal.paymentMethod != oldWidget.proposal.paymentMethod) {
      setState(() {
        _selectedMethod = widget.proposal.paymentMethod;
      });
    }
  }

  // --- PASO 4.2: Función para cambiar y guardar en BD ---
  Future<void> _handleSelectMethod(String? method) async {
    setState(() {
      _selectedMethod = method; // Actualiza la pantalla rápido
    });
    
    // Guarda el cambio en Supabase
    await BudgetProposalService.updatePaymentMethod(widget.proposal.id, method);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedMethod == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selecciona método de pago:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              // --- PASO 4.3: Usar la nueva función _handleSelectMethod ---
              Expanded(child: OutlinedButton.icon(onPressed: () => _handleSelectMethod('cash'), icon: const Icon(Icons.money_off, size: 16), label: const Text('Efectivo'), style: OutlinedButton.styleFrom(foregroundColor: Colors.green))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _handleSelectMethod('digital'), icon: const Icon(Icons.credit_card, size: 16), label: const Text('Digital'), style: OutlinedButton.styleFrom(foregroundColor: Colors.blue))),
            ],
          ),
        ],
      );
    }
    // 2. Si eligió Efectivo
    if (_selectedMethod == 'cash') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          border: Border.all(color: Colors.green),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake, color: Colors.green),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Pago en Efectivo acordado', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Paga directamente al finalizar el servicio.', 
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            TextButton(
              // --- PASO 4.3: Usar la nueva función para resetear ---
              onPressed: () => _handleSelectMethod(null), 
              child: const Text('Cambiar método', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
    // 3. Si eligió Mercado Pago / Digital
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card, color: Colors.blue),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Pago Digital (Mercado Pago)', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '¡ESTARÁ DISPONIBLE PRONTO!',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Estamos trabajando en la integración segura con Mercado Pago.', 
            style: TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          TextButton(
            // --- PASO 4.3: Usar la nueva función para resetear ---
            onPressed: () => _handleSelectMethod(null),
            child: const Text('Elegir otro método', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}