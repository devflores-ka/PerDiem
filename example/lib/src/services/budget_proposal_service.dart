import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final bool isCompleted; // Nuevo campo para marcar si el servicio está completado
  final DateTime? completedAt; // Fecha en que se completó el servicio

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
    this.isCompleted = false,
    this.completedAt,
  });

  factory BudgetProposal.fromJson(Map<String, dynamic> json) => BudgetProposal(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'],
      description: json['description'] ?? '',
      status: json['status'],
      counterProposalId: json['counter_proposal_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
        ? DateTime.parse(json['completed_at'])
        : null,
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
    'is_completed': isCompleted,
    'completed_at': completedAt?.toIso8601String(),
    };
}

class BudgetProposalService {
  static final _supabase = Supabase.instance.client;

  // Crear una nueva propuesta de presupuesto
  static Future<BudgetProposal> createProposal({
    required String roomId,
    required String receiverId,
    required double amount,
    required String description,
  }) async {
    final currentUserId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .insert({
      'room_id': roomId,
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'amount': amount,
      'description': description,
      'status': 'pending',
    })
        .select()
        .single();

    return BudgetProposal.fromJson(response);
  }

  // Crear una contrapropuesta
  static Future<BudgetProposal> createCounterProposal({
    required String originalProposalId,
    required String roomId,
    required String receiverId,
    required double amount,
    required String description,
  }) async {
    final currentUserId = _supabase.auth.currentUser!.id;

    // Primero actualizamos la propuesta original a "countered"
    await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .update({'status': 'countered'})
        .eq('id', originalProposalId);

    // Luego creamos la contrapropuesta
    final response = await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .insert({
      'room_id': roomId,
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'amount': amount,
      'description': description,
      'status': 'pending',
      'counter_proposal_id': originalProposalId,
    })
        .select()
        .single();

    return BudgetProposal.fromJson(response);
  }

  // Aceptar una propuesta
  static Future<void> acceptProposal(String proposalId) async {
    await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .update({'status': 'accepted'})
        .eq('id', proposalId);
  }

  // Rechazar una propuesta
  static Future<void> rejectProposal(String proposalId) async {
    await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .update({'status': 'rejected'})
        .eq('id', proposalId);
  }

  // Obtener propuestas para una sala específica
  static Future<List<BudgetProposal>> getProposalsForRoom(String roomId) async {
    final response = await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((item) => BudgetProposal.fromJson(item))
        .toList();
  }

  // Agregar este método a la clase BudgetProposalService en utils/budget_proposal.dart
  static Future<void> markServiceAsCompleted(String proposalId) async {
    final currentDate = DateTime.now().toIso8601String();

    await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .update({
      'is_completed': true,
      'completed_at': currentDate,
    })
        .eq('id', proposalId);
  }

// También añadir este método a BudgetProposalService para verificar si el servicio está listo para recibir reseñas
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

// Y añadir este método para determinar el rol del usuario en una propuesta
  static Future<String?> getUserRoleInProposal(String proposalId) async {
    final currentUserId = _supabase.auth.currentUser!.id;

    try {
      final response = await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .select()
          .eq('id', proposalId)
          .single();

      final proposal = BudgetProposal.fromJson(response);

      if (proposal.senderId == currentUserId) {
        return 'provider'; // El usuario actual es el proveedor del servicio
      } else if (proposal.receiverId == currentUserId) {
        return 'client'; // El usuario actual es el cliente
      } else {
        return null; // El usuario no está relacionado con esta propuesta
      }
    } catch (e) {
      debugPrint('Error al determinar el rol del usuario: $e');
      return null;
    }
  }

  // Obtener la última propuesta activa en una sala
  static Future<BudgetProposal?> getLatestProposalForRoom(String roomId) async {
    final response = await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .select()
        .eq('room_id', roomId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;

    return BudgetProposal.fromJson(response.first);
  }

  // También necesitamos agregar este método para obtener una propuesta por ID
  static Future<BudgetProposal?> getProposalById(String proposalId) async {
    try {
      final response = await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .select()
          .eq('id', proposalId)
          .single();

      return BudgetProposal.fromJson(response);
    } catch (e) {
      debugPrint('Error al obtener propuesta por ID: $e');
      return null;
    }
  }

  // Métodos para agregar a BudgetProposalService

// Obtener la propuesta aceptada más reciente en una sala
  static Future<BudgetProposal?> getLatestAcceptedProposalForRoom(String roomId) async {
    try {
      final response = await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .select()
          .eq('room_id', roomId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      return BudgetProposal.fromJson(response.first);
    } catch (e) {
      debugPrint('Error al obtener la propuesta aceptada más reciente: $e');
      return null;
    }
  }

// Obtener todas las propuestas aceptadas que aún no han sido completadas
  static Future<List<BudgetProposal>> getAcceptedNotCompletedProposals() async {
    final currentUserId = _supabase.auth.currentUser!.id;

    try {
      final response = await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .select()
          .eq('status', 'accepted')
          .eq('is_completed', false)
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => BudgetProposal.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener propuestas aceptadas no completadas: $e');
      return [];
    }
  }

}

// Widget para mostrar una propuesta de presupuesto en el chat
class BudgetProposalMessage extends StatelessWidget {
  final BudgetProposal proposal;
  final types.User currentUser;
  final Function(BudgetProposal) onAccept;
  final Function(BudgetProposal) onReject;
  final Function(BudgetProposal) onCounter;

  const BudgetProposalMessage({
    super.key,
    required this.proposal,
    required this.currentUser,
    required this.onAccept,
    required this.onReject,
    required this.onCounter,
  });

  bool get isMyProposal => proposal.senderId == currentUser.id;

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.currency(
        locale: 'es_CL',
        symbol: '\$',
        decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMyProposal ? Colors.blue[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyProposal ? Colors.blue[300]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Presupuesto Propuesto',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMyProposal ? Colors.blue[700] : Colors.grey[800],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(proposal.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(proposal.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            numberFormat.format(proposal.amount),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (proposal.description.isNotEmpty) ...[
            const Text(
              'Descripción:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(proposal.description),
            const SizedBox(height: 8),
          ],
          Text(
            'Enviado por: ${isMyProposal ? 'Tú' : 'Contraparte'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(proposal.createdAt.toLocal())}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (proposal.status == 'pending' && !isMyProposal) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 120, // Ancho fijo para cada botón
                    child: ElevatedButton(
                      onPressed: () => onAccept(proposal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aceptar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: () => onReject(proposal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140, // Un poco más ancho para "Contraofertar"
                    child: ElevatedButton(
                      onPressed: () => onCounter(proposal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Contraofertar'),
                    ),
                  ),
                  const SizedBox(width: 16), // Padding final
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'countered':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'accepted':
        return 'Aceptado';
      case 'rejected':
        return 'Rechazado';
      case 'countered':
        return 'Contraofertado';
      default:
        return 'Desconocido';
    }
  }
}