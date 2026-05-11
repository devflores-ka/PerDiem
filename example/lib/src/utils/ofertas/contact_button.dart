// lib/widgets/ofertas/contact_button.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:perdiem_app/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

import '../../pages/auth/auth.dart';
import '../../pages/chat/room.dart';
import '../../services/notification_service.dart';
import '../../services/offers_service.dart';

class ContactButton extends StatefulWidget {
  final String offerId;
  final String offerName;
  final String receiverId; // <--- NUEVO: ID del dueño de la oferta

  const ContactButton({
    super.key,
    required this.offerId,
    required this.offerName,
    required this.receiverId, // <--- AHORA ES REQUERIDO
  });

  @override
  State<ContactButton> createState() => _ContactButtonState();
}

class _ContactButtonState extends State<ContactButton> {
  bool _isLoading = false;
  final OffersService _offersService = OffersService();

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handleContact() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    debugPrint('🚀 Iniciando _handleContact');
    debugPrint('📋 Datos: OfertaID=${widget.offerId}, DueñoID=${widget.receiverId}');

    try {
      final supabase = Supabase.instance.client;
      final currentUser = SupabaseChatCore.instance.loggedUser;

      if (currentUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
        return;
      }

      // 1. Usar el ID recibido directamente
      final ownerId = widget.receiverId; 

      if (ownerId == currentUser.id) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cantContactYourself)),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. Buscar información completa del usuario dueño (para validar roles)
      debugPrint('Buscando información del usuario dueño...');
      final userDoc = await supabase
          .schema('chats')
          .from('users')
          .select()
          .eq('id', ownerId)
          .maybeSingle();

      types.User? ownerUser;

      if (userDoc != null) {
        ownerUser = types.User(
          id: userDoc['id'],
          firstName: userDoc['firstName'],
          lastName: userDoc['lastName'],
          imageUrl: userDoc['imageUrl'],
          role: (userDoc['role'] == 'admin') ? types.Role.admin : types.Role.user,
          metadata: userDoc['metadata'],
        );
      }

      if (ownerUser == null) {
        debugPrint('❌ Error: Usuario dueño no encontrado en tabla users');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userNotAvaliable)),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3. Buscar si ya existe un chat para esta oferta específica
      final rooms = await SupabaseChatCore.instance.rooms();
      
      final room = rooms.firstWhereOrNull((room) =>
        room.metadata != null &&
        room.metadata!['offer_id'] == widget.offerId &&
        room.users.any((u) => u.id == currentUser.id), // Asegurar que sea MI chat
      );

      types.Room chatRoom;
      
      if (room != null) {
        // --- CASO: SALA EXISTENTE ---
        chatRoom = room;
        debugPrint('✅ Usando sala existente - ID: ${room.id}');

        // Lógica de migración legacy (si la sala era vieja y tenía otro tipo)
        if (room.type == 'offer_group') {
           await supabase.schema('chats').from('rooms')
               .update({'type': 'group'}).eq('id', room.id);
        }
        
        // Asegurarnos que ambos estén en la lista de userIds (reparación)
        final currentParticipants = room.users.map((u) => u.id).toList();
        if (!currentParticipants.contains(currentUser.id) || !currentParticipants.contains(ownerId)) {
             final updatedUserIds = {...currentParticipants, currentUser.id, ownerId}.toList();
             await supabase.schema('chats').from('rooms')
                 .update({'userIds': updatedUserIds, 'updatedAt': DateTime.now().millisecondsSinceEpoch})
                 .eq('id', room.id);
        }

      } else {
        // --- CASO: SALA NUEVA (Creación Manual para Metadata) ---
        debugPrint('🏗️ Creando nueva sala...');
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final roomId = timestamp; // ID numérico simple basado en tiempo

        await supabase.schema('chats').from('rooms').insert({
          'id': roomId,
          'name': widget.offerName,
          'type': 'group',
          'userIds': [currentUser.id, ownerId],
          'metadata': {
            'offer_id': widget.offerId,     // <--- ESTO LEE EL ADMIN PANEL
            'offer_name': widget.offerName, // <--- ESTO TAMBIÉN
            'creator_id': currentUser.id,
            'owner_id': ownerId,
            'room_type': 'offer_chat',
          },
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });

        // Esperar propagación
        await Future.delayed(const Duration(milliseconds: 500));

        // Recuperar la sala creada
        final newRooms = await SupabaseChatCore.instance.rooms();
        final newRoom = newRooms.firstWhereOrNull((r) => 
            r.id == roomId.toString() || 
            (r.metadata?['offer_id'] == widget.offerId)
        );

        if (newRoom == null) {
           throw Exception("Error al recuperar la sala creada");
        }
        chatRoom = newRoom;
      }

      // 4. Registrar como aplicante (si no lo es)
      final alreadyApplied = await supabase
          .schema('jobs')
          .from('offer_applicants')
          .select()
          .eq('offer_id', widget.offerId)
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (alreadyApplied == null) {
        await _offersService.applyToOffer(
          offerId: widget.offerId,
          userId: currentUser.id,
        );
      }

      // 5. Notificación
      await NotificationService.sendNewChatNotification(
        ownerId,
        widget.offerName,
      );

      // 6. Navegar
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RoomPage(room: chatRoom),
        ),
      );

    } catch (e) {
      debugPrint('❌ ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorContact}: {$e}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: _isLoading ? null : _handleContact,
      child: _isLoading
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(l10n.contact),
    ),
  );
  }
}