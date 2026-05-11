// Archivo: lib/screens/negotiation_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:perdiem_app/flutter_supabase_chat_core.dart';

import '../../services/budget_proposal_service.dart';
import '../../widgets/user_negotiation.dart';
import '../chat/room.dart';

class NegotiationDetailsScreen extends StatelessWidget {
  final RoomNegotiation negotiation;

  const NegotiationDetailsScreen({
    super.key,
    required this.negotiation,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser!.id;
    final numberFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Propuestas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RoomPage(room: negotiation.room),
                ),
              );
            },
            tooltip: 'Ir al chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Encabezado con información de la negociación
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  negotiation.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(negotiation.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(negotiation.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${negotiation.proposals.length} propuesta${negotiation.proposals.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Timeline de propuestas
          Expanded(
            child: negotiation.proposals.isEmpty
                ? const Center(
              child: Text('No hay propuestas en esta negociación'),
            )
                : ListView.builder(
              itemCount: negotiation.proposals.length,
              itemBuilder: (context, index) {
                // Ordenar por fecha descendente
                final sortedProposals = List<BudgetProposal>.from(negotiation.proposals)
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final proposal = sortedProposals[index];
                final isMine = proposal.senderId == currentUserId;

                return _buildProposalTimelineItem(
                  context,
                  proposal,
                  isMine,
                  numberFormat,
                  isLatest: index == 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalTimelineItem(
      BuildContext context,
      BudgetProposal proposal,
      bool isMine,
      NumberFormat numberFormat, {
        bool isLatest = false,
      }) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        color: isLatest ? Colors.yellow[50] : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Línea de tiempo y punto
            Container(
              width: 50,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getStatusColor(proposal.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido de la propuesta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información de quién y cuándo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isMine ? 'Tu propuesta' : 'Propuesta recibida',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMine ? Colors.blue[700] : Colors.grey[800],
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(
                          proposal.createdAt.toLocal(),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Monto
                  Row(
                    children: [
                      const Text(
                        'Monto:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        numberFormat.format(proposal.amount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Descripción si existe
                  if (proposal.description.isNotEmpty) ...[
                    const Text(
                      'Descripción:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      child: Text(proposal.description),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Etiqueta de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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

                  // Si es una contrapropuesta, mostrar información sobre la propuesta original
                  if (proposal.counterProposalId != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.reply,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Esta es una contrapropuesta',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

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