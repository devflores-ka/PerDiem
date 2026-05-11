// Archivo: lib/services/negotiations_service.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:perdiem_app/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'budget_proposal_service.dart';

class NegotiationsService {
  static final _supabase = Supabase.instance.client;

  // Obtener todas las negociaciones en las que el usuario está involucrado
  static Future<List<BudgetProposal>> getUserNegotiations() async {
    final currentUserId = _supabase.auth.currentUser!.id;

    // 1. Primero obtener solo las propuestas sin unir con users
    final response = await _supabase
        .schema('jobs')
        .from('budget_proposals')
        .select()
        .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
        .order('created_at', ascending: false);

    // 2. Crear una lista para almacenar las propuestas con información completa
    final proposals = <BudgetProposal>[];

    // 3. Para cada propuesta, obtener la información del remitente y destinatario
    for (var item in response) {
      // Convertir los datos de la propuesta a un modelo
      final proposal = BudgetProposal.fromJson(item);

      // Obtener datos del remitente
      if (item['sender_id'] != null) {
        try {
          final senderData = await _supabase
              .schema('chats')
              .from('users')
              .select('id, firstName, lastName, imageUrl')
              .eq('id', item['sender_id'])
              .single();

          // Aquí puedes agregar la info del remitente a la propuesta
          // Por ejemplo, si tienes un campo para esto en tu modelo:
          // proposal.senderInfo = senderData;
        } catch (e) {
          debugPrint('Error al obtener datos del remitente: $e');
        }
      }

      // Obtener datos del destinatario
      if (item['receiver_id'] != null) {
        try {
          final receiverData = await _supabase
              .schema('chats')
              .from('users')
              .select('id, firstName, lastName, imageUrl')
              .eq('id', item['receiver_id'])
              .single();

          // Aquí puedes agregar la info del destinatario a la propuesta
          // proposal.receiverInfo = receiverData;
        } catch (e) {
          debugPrint('Error al obtener datos del destinatario: $e');
        }
      }

      proposals.add(proposal);
    }

    return proposals;
  }

  // Obtener resumen de negociaciones (agrupadas por sala)
  static Future<Map<String, List<BudgetProposal>>> getNegotiationsByRoom() async {
    final proposals = await getUserNegotiations();

    // Agrupar por sala
    final roomProposals = <String, List<BudgetProposal>>{};

    for (var proposal in proposals) {
      if (!roomProposals.containsKey(proposal.roomId)) {
        roomProposals[proposal.roomId] = [];
      }
      roomProposals[proposal.roomId]!.add(proposal);
    }

    return roomProposals;
  }

  // Obtener información de salas para las negociaciones
  // Corregir la función getRoomsInfo en negotiations_service.dart
  static Future<Map<String, types.Room>> getRoomsInfo(List<String> roomIds) async {
    final result = <String, types.Room>{};

    // Obtener cada sala y agregarla al mapa solo si no es nula
    await Future.forEach(roomIds, (String id) async {
      try {
        final room = await SupabaseChatCore.instance.getRoom(id);
        if (room != null) {  // Verificar que la sala no sea nula
          result[id] = room;
        }
      } catch (e) {
        debugPrint('Error al obtener información de la sala $id: $e');
        // Continuamos con la siguiente sala si hay error
      }
    });

    return result;
  }
}