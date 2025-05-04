import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../class/message_status_ex.dart';
import '../util.dart';

class RoomTile extends StatelessWidget {
  final types.Room room;
  final ValueChanged<types.Room> onTap;

  const RoomTile({
    super.key,
    required this.room,
    required this.onTap,
  });

  Widget _buildAvatar(types.Room room) {
    final color = getAvatarColor(room.id);
    var otherUserIndex = -1;
    types.User? otherUser;

    // Determinar el tipo de sala y manejar según corresponda
    if (room.type == types.RoomType.direct) {
      otherUserIndex = room.users.indexWhere(
            (u) => u.id != SupabaseChatCore.instance.loggedSupabaseUser!.id,
      );
      if (otherUserIndex >= 0) {
        otherUser = room.users[otherUserIndex];
      }
    }

    // Para el tipo offer_group, usamos la primera letra del nombre de la oferta
    final isOfferGroup = room.metadata != null && room.metadata!['offer_id'] != null;
    final hasImage = room.imageUrl != null;

    // Decidir qué nombre mostrar
    var name = '';
    if (isOfferGroup) {
      name = room.metadata!['offer_name'] ?? room.name ?? '';
    } else {
      name = room.name ?? '';
    }

    final Widget child = CircleAvatar(
      backgroundColor: hasImage ? Colors.transparent : color,
      backgroundImage: hasImage ? NetworkImage(room.imageUrl!) : null,
      radius: 20,
      child: !hasImage
          ? Text(
        name.isEmpty ? '' : name[0].toUpperCase(),
        style: const TextStyle(color: Colors.white),
      )
          : null,
    );

    // Solo mostrar status online para chats directos, no para grupos
    if (otherUser == null || isOfferGroup) {
      return Padding(
        padding: const EdgeInsets.only(right: 16),
        child: isOfferGroup
            ? Stack(
          alignment: Alignment.bottomRight,
          children: [
            child,
            // Indicador visual para salas de tipo oferta
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(
                right: 2,
                bottom: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ],
        )
            : child,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: UserOnlineStatusWidget(
        uid: otherUser.id,
        builder: (status) => Stack(
          alignment: Alignment.bottomRight,
          children: [
            child,
            if (status == UserOnlineStatus.online)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(
                  right: 3,
                  bottom: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getRoomName() {
    // Manejar salas de tipo oferta
    if (room.metadata != null && room.metadata!['offer_id'] != null) {
      return room.metadata!['offer_name'] ?? 'Oferta sin nombre';
    }

    // Para salas directas, usar el nombre del otro usuario
    if (room.type == types.RoomType.direct) {
      final otherUserIndex = room.users.indexWhere(
            (u) => u.id != SupabaseChatCore.instance.loggedSupabaseUser!.id,
      );

      if (otherUserIndex >= 0) {
        final otherUser = room.users[otherUserIndex];
        final firstName = otherUser.firstName ?? '';
        final lastName = otherUser.lastName ?? '';

        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          return '$firstName $lastName'.trim();
        }
      }
    }

    // Fallback al nombre de la sala
    return room.name ?? '';
  }

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey(room.id),
    leading: _buildAvatar(room),
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              // Mostrar icono para grupos de ofertas
              if (room.metadata != null && room.metadata!['offer_id'] != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Icon(Icons.handshake, size: 16, color: Colors.orange),
                ),
              Flexible(
                child: Text(
                  _getRoomName(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (room.lastMessages?.isNotEmpty == true)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeago.format(
                  DateTime.now().subtract(
                    Duration(
                      milliseconds: DateTime.now().millisecondsSinceEpoch -
                          (room.updatedAt ?? 0),
                    ),
                  ),
                  locale: 'es',
                ),
              ),
              if (room.lastMessages!.first.status != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    size: 20,
                    room.lastMessages!.first.status!.icon,
                    color:
                    room.lastMessages!.first.status == types.Status.seen
                        ? Colors.lightBlue
                        : null,
                  ),
                ),
            ],
          ),
      ],
    ),
    subtitle: room.lastMessages?.isNotEmpty == true &&
        room.lastMessages!.first is types.TextMessage
        ? Text(
      (room.lastMessages!.first as types.TextMessage).text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    )
        : null,
    onTap: () => onTap(room),
  );
}