// lib/models/user_negotiation.dart

import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:intl/intl.dart';
import 'package:perdiem_app/flutter_supabase_chat_core.dart';

import '/l10n/generated/app_localizations.dart';
import '../services/budget_proposal_service.dart';

class RoomNegotiation {
  final types.Room room;
  final List<BudgetProposal> proposals;
  final BudgetProposal? latestProposal;

  RoomNegotiation({
    required this.room,
    required this.proposals,
    this.latestProposal,
  });

  // Determinar el estado general de la negociación
  String get status {
    if (latestProposal == null) return 'unknown';

    return latestProposal!.status;
  }

  // Obtener el título para mostrar (nombre del otro usuario o nombre de la sala)
  String get title {
    final roomName = room.name;
    if (roomName != null && roomName.isNotEmpty) {
      return roomName;
    }

    // Si no hay nombre de sala, mostrar el nombre del otro usuario
    if (room.users.length > 1) {
      // Encuentra al otro usuario (no al usuario actual)
      final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser!.id;
      final otherUser = room.users.firstWhere(
            (user) => user.id != currentUserId,
        orElse: () => types.User(id: ''),
      );

      if (otherUser.id.isNotEmpty) {
        return otherUser.firstName ?? otherUser.lastName ?? 'Usuario';
      }
    }

    return 'Conversación';
  }

  // Obtener el subtítulo (detalles de la última propuesta)
  String get subtitle {
    if (latestProposal == null) return 'Sin propuestas';

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );

    final amount = currencyFormat.format(latestProposal!.amount);
    final statusText = _getStatusText(latestProposal!.status);

    final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser!.id;
    final isSender = latestProposal!.senderId == currentUserId;

    if (isSender) {
      return 'Tu oferta: $amount - $statusText';
    } else {
      return 'Te ofrecieron: $amount - $statusText';
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