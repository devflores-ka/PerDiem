// Archivo: lib/widgets/ofertas/contact_button.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pages/auth/auth.dart';
import '../../pages/chat/room.dart';
import '../../services/notification_service.dart';
import '../../services/offers_service.dart';

class ContactButton extends StatefulWidget {
  final String offerId;
  final String offerName;

  const ContactButton({
    super.key,
    required this.offerId,
    required this.offerName,
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
    if (_isLoading) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    // Logs iniciales
    debugPrint('🚀 Iniciando _handleContact');
    debugPrint('📋 Datos de la oferta - ID: ${widget.offerId}, Nombre: ${widget.offerName}');

    try {
      final supabase = Supabase.instance.client;
      debugPrint('✅ Cliente Supabase inicializado');

      // Verificar que el usuario esté logueado primero
      final currentUser = SupabaseChatCore.instance.loggedUser;
      debugPrint('👤 Usuario actual: ${currentUser?.id ?? 'No hay usuario logueado'}');

      if (currentUser == null) {
        debugPrint('❌ Error: Usuario no logueado');
        if (!mounted) return;

        // En lugar de mostrar un SnackBar, redirigir directamente a la página de autenticación
        setState(() => _isLoading = false);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
        return;
      }

      // 1. Obtener el user_id del dueño de la oferta
      debugPrint('🔍 Consultando dueño de oferta ID: ${widget.offerId} en schema: jobs, tabla: offers');
      try {
        final response = await supabase
            .schema('jobs')
            .from('offers')
            .select('user_id')
            .eq('id', widget.offerId)
            .maybeSingle();

        debugPrint('📊 Respuesta de consulta de oferta: $response');

        if (response == null) {
          debugPrint('⚠️ Oferta no encontrada con ID: ${widget.offerId}');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oferta no encontrada')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final ownerId = response['user_id'];
        debugPrint('✅ Dueño de la oferta encontrado - ID: $ownerId');

        if (ownerId == currentUser.id) {
          debugPrint('⚠️ Usuario intentando contactar su propia oferta');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No puedes contactar tu propia oferta')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // 2. Buscar usuario del dueño con rol correcto
        debugPrint('🔍 Buscando información del usuario dueño');
        final users = await SupabaseChatCore.instance.users();
        debugPrint('📊 Total de usuarios obtenidos: ${users.length}');

        final ownerUser = users.firstWhereOrNull((u) => u.id == ownerId);
        debugPrint('👤 Usuario dueño encontrado: ${ownerUser != null ? 'Sí' : 'No'}');

        if (ownerUser == null) {
          debugPrint('❌ Error: Usuario dueño no encontrado ID: $ownerId');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo encontrar al usuario dueño de la oferta')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // 3. Buscar si ya existe un chat para esta oferta específica
        debugPrint('🔍 Verificando si existe una sala de chat para esta oferta');
        final rooms = await SupabaseChatCore.instance.rooms();
        debugPrint('📊 Total de salas obtenidas: ${rooms.length}');

        final room = rooms.firstWhereOrNull((room) =>
        room.metadata != null &&
            room.metadata!['offer_id'] == widget.offerId,
        );

        debugPrint('🏠 Sala existente para esta oferta: ${room != null ? 'Sí - ID: ${room.id}' : 'No'}');

        // Si no existe sala para esta oferta específica, crear una nueva
        types.Room chatRoom;
        if (room != null) {
          chatRoom = room;
          debugPrint('✅ Usando sala existente - ID: ${room.id}, Tipo: ${room.type}');

          // Si la sala existente tiene tipo 'offer_group', actualizarlo a 'group'
          if (room.type == 'offer_group') {
            debugPrint('🔄 Actualizando tipo de sala de offer_group a group');
            await supabase
                .schema('chats')
                .from('rooms')
                .update({
              'type': 'group',
            })
                .eq('id', room.id);

            // Esperar un momento para que Supabase procese
            debugPrint('⏳ Esperando procesamiento de Supabase...');
            await Future.delayed(const Duration(milliseconds: 300));

            // Recargar la sala con el tipo actualizado
            debugPrint('🔄 Recargando salas para obtener información actualizada');
            final updatedRooms = await SupabaseChatCore.instance.rooms();
            final updatedRoom = updatedRooms.firstWhere((r) => r.id == room.id);
            chatRoom = updatedRoom;
            debugPrint('✅ Sala actualizada - Nuevo tipo: ${chatRoom.type}');
          }

          // Verificar si el usuario actual ya está en la sala
          final userInRoom = chatRoom.users.any((u) => u.id == currentUser.id);
          debugPrint('👤 Usuario actual ya está en la sala: ${userInRoom ? 'Sí' : 'No'}');

          if (!userInRoom) {
            // Añadir el usuario actual a la sala existente
            debugPrint('➕ Añadiendo usuario actual a la sala existente');
            final userIds = List<String>.from(room.users.map((u) => u.id));
            userIds.add(currentUser.id);
            debugPrint('📊 Lista actualizada de userIds: $userIds');

            await supabase
                .schema('chats')
                .from('rooms')
                .update({
              'userIds': userIds,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            })
                .eq('id', room.id);

            // Recargar la sala con los participantes actualizados
            debugPrint('🔄 Recargando salas para obtener participantes actualizados');
            final updatedRooms = await SupabaseChatCore.instance.rooms();
            final updatedRoom = updatedRooms.firstWhere((r) => r.id == room.id);
            chatRoom = updatedRoom;
            debugPrint('✅ Sala actualizada con nuevo participante');
          }
        } else {
          // Crear manualmente la sala en Supabase como grupo de oferta
          debugPrint('🏗️ Creando nueva sala de chat para la oferta');
          final currentUserId = currentUser.id;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          debugPrint('⏱️ Usando timestamp: $timestamp');

          // Generar un ID único para la sala basado en la oferta
          final roomId = timestamp; // Genera un ID numérico único basado en el timestamp actual
          debugPrint('🆔 ID generado para la sala: $roomId');

          // Insertar en la tabla rooms
          debugPrint('💾 Insertando nueva sala en la base de datos');
          await supabase
              .schema('chats')
              .from('rooms').insert({
            'id': roomId,
            'name': widget.offerName, // Nombre de la sala basado en la oferta
            'type': 'group', // Tipo específico para grupos de ofertas
            'userIds': [currentUserId, ownerId], // Array de IDs de usuario (inicialmente creador y dueño)
            'metadata': {
              'offer_id': widget.offerId,
              'offer_name': widget.offerName,
              'createdAt': timestamp,
              'creator_id': currentUserId,
              'owner_id': ownerId, // Identificar al dueño de la oferta
              'room_type': 'offer_group',
            },
            'createdAt': timestamp,
            'updatedAt': timestamp,
          });

          // Esperar un momento para que Supabase procese
          debugPrint('⏳ Esperando procesamiento de Supabase...');
          await Future.delayed(const Duration(milliseconds: 500));

          // Recuperar la sala recién creada
          debugPrint('🔍 Buscando la sala recién creada');
          final newRooms = await SupabaseChatCore.instance.rooms();
          debugPrint('📊 Total de salas después de crear: ${newRooms.length}');

          final newRoom = newRooms.firstWhereOrNull((room) =>
          room.metadata != null &&
              room.metadata!['offer_id'] == widget.offerId,
          );

          debugPrint('🏠 Sala nueva encontrada: ${newRoom != null ? 'Sí - ID: ${newRoom.id}' : 'No'}');

          if (newRoom == null) {
            debugPrint('❌ Error: No se pudo encontrar la sala recién creada');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al crear la sala de chat')),
            );
            setState(() => _isLoading = false);
            return;
          }

          chatRoom = newRoom;
          debugPrint('✅ Nueva sala creada y recuperada correctamente');
        }

        // 4. Registrar como aplicante si no lo ha hecho antes
        debugPrint('🔍 Verificando si el usuario ya aplicó a esta oferta');
        final alreadyApplied = await supabase
            .schema('jobs')
            .from('offer_applicants')
            .select()
            .eq('offer_id', widget.offerId)
            .eq('user_id', currentUser.id)
            .maybeSingle();

        debugPrint('📊 Usuario ya aplicó: ${alreadyApplied != null ? 'Sí' : 'No'}');

        if (alreadyApplied == null) {
          debugPrint('📝 Registrando usuario como aplicante');
          // Usar el método del servicio en lugar de acceso directo a Supabase
          final applySuccess = await _offersService.applyToOffer(
            offerId: widget.offerId,
            userId: currentUser.id,
          );

          if (applySuccess) {
            debugPrint('✅ Usuario registrado como aplicante');
          } else {
            debugPrint('⚠️ No se pudo registrar como aplicante');
          }
        }

        // Notificar al anunciante
        debugPrint('📨 Enviando notificación al dueño de la oferta (ID: $ownerId)');
        if (ownerId.isEmpty) {
          debugPrint('⚠️ El ID del dueño está vacío, no se puede enviar notificación');
          return;
        }

        try {
          // Verificar que tenemos los datos necesarios
          debugPrint('📝 Detalles: OwnerId=$ownerId, OfferName=${widget.offerName}');

          // Enviar la notificación
          await NotificationService.sendNewChatNotification(
            ownerId,
            widget.offerName,
          );
          debugPrint('✅ Notificación enviada correctamente');
        } catch (notifError) {
          debugPrint('⚠️ Error al enviar notificación: $notifError');
          debugPrint('Stack trace: ${StackTrace.current}');
          // Continuamos aunque falle la notificación
        }

        // 5. Ir al chat
        debugPrint('🚀 Navegando a la sala de chat');
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RoomPage(room: chatRoom),
          ),
        );
        debugPrint('↩️ Regresando de la sala de chat');
      } catch (dbError) {
        debugPrint('❌ ERROR EN CONSULTA DE BASE DE DATOS: $dbError');
        if (dbError.toString().contains('PGRST116')) {
          debugPrint('🔍 Error PGRST116 - No se encontraron resultados o se encontraron múltiples');
        }
        rethrow; // Relanzar para que sea capturado por el try/catch principal
      }
    } catch (e) {
      debugPrint('❌ ERROR GENERAL: $e');
      debugPrint('📜 STACK TRACE: ${StackTrace.current}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al contactar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('🏁 Finalizada función _handleContact');
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: _isLoading ? null : _handleContact,
      child: _isLoading
          ? const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      )
          : const Text('Contactar'),
    ),
  );
}