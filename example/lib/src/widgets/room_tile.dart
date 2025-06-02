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
      final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser?.id;
      if (currentUserId != null) {
        otherUserIndex = room.users.indexWhere(
              (u) => u.id != currentUserId,
        );
        if (otherUserIndex >= 0) {
          otherUser = room.users[otherUserIndex];
          debugPrint('🔍 RoomTile: Otro usuario encontrado: "${otherUser.firstName} ${otherUser.lastName}" (${otherUser.id})');
        } else {
          debugPrint('❌ RoomTile: No se encontró otro usuario. Total usuarios: ${room.users.length}');
          debugPrint('❌ RoomTile: Usuario actual: $currentUserId');
          debugPrint('❌ RoomTile: Usuarios en room: ${room.users.map((u) => "${u.firstName} ${u.lastName} (${u.id})").join(", ")}');
        }
      }
    }

    // Para el tipo offer_group, usamos la primera letra del nombre de la oferta
    final isOfferGroup = room.metadata != null && room.metadata!['offer_id'] != null;

    // ✅ CORREGIDO: Para chats directos, usar datos del OTRO usuario
    String? imageUrl;
    String name = '';

    if (isOfferGroup) {
      name = room.metadata!['offer_name'] ?? room.name ?? '';
      imageUrl = room.imageUrl;
    } else if (room.type == types.RoomType.direct && otherUser != null) {
      // ✅ USAR DATOS DEL OTRO USUARIO
      final firstName = otherUser.firstName ?? '';
      final lastName = otherUser.lastName ?? '';
      name = '$firstName $lastName'.trim();
      imageUrl = otherUser.imageUrl;

      debugPrint('🖼️ RoomTile: Avatar para "$name", imagen: $imageUrl');
    } else {
      name = room.name ?? '';
      imageUrl = room.imageUrl;
    }

    final hasImage = imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'https://placehold.co/100';

    final Widget child = CircleAvatar(
      backgroundColor: hasImage ? Colors.transparent : color,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
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
      final offerName = room.metadata!['offer_name'] ?? 'Oferta sin nombre';
      debugPrint('🏷️ RoomTile: Nombre de oferta: "$offerName"');
      return offerName;
    }

    if (room.type == types.RoomType.direct) {
      final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser?.id;

      if (currentUserId != null) {
        // ✅ CORREGIDO: Buscar al OTRO usuario (no al usuario actual)
        final otherUserIndex = room.users.indexWhere(
              (u) => u.id != currentUserId,
        );

        if (otherUserIndex >= 0) {
          final otherUser = room.users[otherUserIndex];
          final firstName = otherUser.firstName ?? '';
          final lastName = otherUser.lastName ?? '';

          if (firstName.isNotEmpty || lastName.isNotEmpty) {
            final userName = '$firstName $lastName'.trim();
            debugPrint('🏷️ RoomTile: Nombre del otro usuario: "$userName" (ID: ${otherUser.id})');
            return userName;
          } else {
            debugPrint('⚠️ RoomTile: El otro usuario no tiene nombre');
            return 'Usuario sin nombre';
          }
        } else {
          debugPrint('❌ RoomTile: No se encontró otro usuario en chat directo');
          debugPrint('❌ RoomTile: Total usuarios: ${room.users.length}');
          debugPrint('❌ RoomTile: Usuario actual: $currentUserId');
          debugPrint('❌ RoomTile: IDs en room: ${room.users.map((u) => u.id).join(", ")}');
          return 'Chat incompleto';
        }
      }
    }

    // Último fallback
    debugPrint('🏷️ RoomTile: Usando fallback: ${room.name ?? "Chat sin nombre"}');
    return room.name ?? 'Chat sin nombre';
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
                    color: room.lastMessages!.first.status == types.Status.seen
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