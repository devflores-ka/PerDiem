// Archivo: lib/screens/negotiations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:intl/intl.dart';
import '../../services/negotiations_service.dart';
import '../../widgets/user_negotiation.dart';
import '../chat/room.dart';

class NegotiationsScreen extends StatefulWidget {
  const NegotiationsScreen({super.key});

  @override
  State<NegotiationsScreen> createState() => _NegotiationsScreenState();
}

class _NegotiationsScreenState extends State<NegotiationsScreen> {
  bool _isLoading = true;
  List<RoomNegotiation> _negotiations = [];
  String _selectedFilter = 'all'; // all, pending, accepted, rejected

  @override
  void initState() {
    super.initState();
    _loadNegotiations();
  }

  Future<void> _loadNegotiations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener propuestas agrupadas por sala
      final roomProposals = await NegotiationsService.getNegotiationsByRoom();

      // Obtener información de las salas
      final roomIds = roomProposals.keys.toList();
      final roomsInfo = await NegotiationsService.getRoomsInfo(roomIds);

      // Crear objetos de negociación para cada sala
      final negotiations = <RoomNegotiation>[];

      for (final roomId in roomProposals.keys) {
        if (roomsInfo.containsKey(roomId)) {
          final proposals = roomProposals[roomId]!;

          // Encontrar la propuesta más reciente
          proposals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final latestProposal = proposals.isNotEmpty ? proposals.first : null;

          negotiations.add(RoomNegotiation(
            room: roomsInfo[roomId]!,
            proposals: proposals,
            latestProposal: latestProposal,
            ),
          );
        }
      }

      setState(() {
        _negotiations = negotiations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar negociaciones: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar negociaciones: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<RoomNegotiation> get filteredNegotiations {
    if (_selectedFilter == 'all') {
      return _negotiations;
    }

    return _negotiations.where((negotiation) {
      final status = negotiation.latestProposal?.status ?? '';
      return status == _selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Mis Negociaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNegotiations,
            tooltip: 'Actualizar',
          ),
        ],
        backgroundColor: Colors.blue,
      ),
    backgroundColor: Colors.white,
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todas', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pendientes', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Aceptadas', 'accepted'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rechazadas', 'rejected'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Contraofertadas', 'countered'),
                ],
              ),
            ),
          ),

          // Lista de negociaciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredNegotiations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              itemCount: filteredNegotiations.length,
              itemBuilder: (context, index) => _buildNegotiationItem(filteredNegotiations[index]),
            ),
          ),
        ],
      ),
    );

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Colors.white, // Cambia el color del checkmark a blanco
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87, // Cambia el color a blanco cuando está seleccionado
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.money_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all'
                ? 'No tienes negociaciones'
                : 'No tienes negociaciones con el estado seleccionado',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_selectedFilter != 'all')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'all';
                });
              },
              child: const Text('Ver todas las negociaciones'),
            ),
        ],
      ),
    );

  Widget _buildNegotiationItem(RoomNegotiation negotiation) {
    // Formato de moneda
    final numberFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );

    // Color según estado
    final statusColor = _getStatusColor(negotiation.status);

    // Mostrar avatar del otro usuario
    final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser!.id;
    final otherUser = negotiation.room.users.firstWhere(
          (user) => user.id != currentUserId,
      orElse: () => types.User(id: ''),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RoomPage(room: negotiation.room),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con avatar y nombre
              Row(
                children: [
                  if (otherUser.id.isNotEmpty)
                    CircleAvatar(
                      backgroundImage: otherUser.imageUrl != null
                          ? NetworkImage(otherUser.imageUrl!)
                          : null,
                      child: otherUser.imageUrl == null
                          ? Text(otherUser.firstName?[0] ?? '?')
                          : null,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          negotiation.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
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
                            if (negotiation.latestProposal != null)
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                  negotiation.latestProposal!.createdAt.toLocal(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Detalles de la última propuesta
              if (negotiation.latestProposal != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Último monto:',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      numberFormat.format(negotiation.latestProposal!.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (negotiation.latestProposal!.description.isNotEmpty) ...[
                  Text(
                    'Descripción:',
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    negotiation.latestProposal!.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Indicador de quién envió la última propuesta
                Row(
                  children: [
                    Icon(
                      negotiation.latestProposal!.senderId == currentUserId
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      negotiation.latestProposal!.senderId == currentUserId
                          ? 'Enviaste esta propuesta'
                          : 'Recibiste esta propuesta',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],

              // Mostrar cantidad de propuestas totales en esta negociación
              const SizedBox(height: 8),
              Text(
                '${negotiation.proposals.length} propuesta${negotiation.proposals.length != 1 ? 's' : ''} en total',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
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