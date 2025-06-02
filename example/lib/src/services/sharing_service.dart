import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SharingService {
  // URL base for sharing offers with preview
  // This points to your Supabase Edge Function
  static const String _baseShareUrl = 'https://obebqaertspxottkblzm.supabase.co/functions/v1/compartir';

  // Method to share externally using system's native share selector
  static Future<void> compartirOferta({
    required BuildContext context,
    required String offerId,
    required String offerName,
    required String descripcion,
    required double presupuesto,
    required String nombreUsuario,
    required double calificacion,
    required String numResenas,
    required String imagenUrl,
  }) async {
    // Create URL for rich preview using the Edge Function
    final shareUrl = '$_baseShareUrl/$offerId';

    try {
      // Create a message formatted for different platforms
      // This puts the URL at the end for better preview generation
      final mensajeComparte =
          '🔍 $offerName\n\n'
          '💼 $descripcion\n\n'
          '💰 Presupuesto: \$${presupuesto.toString()}\n\n'
          '👤 Publicado por: $nombreUsuario\n\n'
          '⭐ Calificación: $calificacion ($numResenas reseñas)\n\n'
          '$shareUrl';

      // Use the share method
      await Share.share(
        mensajeComparte,
        subject: '¡Mira esta oferta de $offerName!',
      );

      debugPrint('Offer shared successfully');
    } catch (e) {
      debugPrint('Error sharing: $e');

      // Fallback: copy to clipboard if sharing failed
      await Clipboard.setData(ClipboardData(text: shareUrl));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copiado al portapapeles')),
        );
      }
    }
  }

  // Método para generar URL de app o tienda
  static Future<void> abrirAppOTienda({
    required BuildContext context,
    required String offerId,
  }) async {
    // Crear las URLs para diferentes destinos
    final appUri = 'perdiem://offers/$offerId'; // URI para abrir la app directamente
    final playStoreUrl = 'https://play.google.com/store/apps/details?id=cl.perdiem.app'; // Ajusta con tu ID real
    final appStoreUrl = 'https://apps.apple.com/app/idTUAPPID'; // Ajusta con tu ID real

    try {
      // Intentar abrir la app primero
      final appUriParsed = Uri.parse(appUri);
      if (await canLaunchUrl(appUriParsed)) {
        await launchUrl(appUriParsed);
        return;
      }

      // Si la app no está instalada, detectamos la plataforma y abrimos la tienda correspondiente
      if (Platform.isAndroid) {
        final uri = Uri.parse(playStoreUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      } else if (Platform.isIOS) {
        final uri = Uri.parse(appStoreUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }

      // Si todo falla, mostramos un mensaje
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la tienda de aplicaciones')),
        );
      }
    } catch (e) {
      debugPrint('Error abriendo app o tienda: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al intentar abrir la app')),
        );
      }
    }
  }

  // Method specifically for sharing on WhatsApp with rich preview
  static Future<void> compartirEnWhatsApp({
    required BuildContext context,
    required String offerId,
    required String offerName,
    required String descripcion,
    required double presupuesto,
    required String imagenUrl,
  }) async {
    try {
      // URL for rich preview using the Edge Function
      final shareUrl = '$_baseShareUrl/$offerId';

      // For WhatsApp, a shorter message works better
      // Put the URL at the end for better preview
      final mensajeWhatsApp =
          '¡Mira esta oferta: $offerName!\n\n$shareUrl';

      final encodedText = Uri.encodeComponent(mensajeWhatsApp);
      final whatsappUrl = 'whatsapp://send?text=$encodedText';

      final canLaunch = await canLaunchUrl(Uri.parse(whatsappUrl));

      if (canLaunch) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        // Fallback to general sharing if WhatsApp isn't installed
        await Share.share(mensajeWhatsApp);
      }
    } catch (e) {
      debugPrint('Error sharing to WhatsApp: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  // Share with a specific platform
  static Future<void> compartirEnPlataforma({
    required BuildContext context,
    required String offerId,
    required String offerName,
    required String descripcion,
    required double presupuesto,
    required String imagenUrl,
    required String plataforma,
    String? nombreUsuario,
    double? calificacion,
    String? numResenas,
  }) async {
    // Default values if not provided
    final nombre = nombreUsuario ?? 'Usuario';
    final rating = calificacion ?? 4.5;
    final reviews = numResenas ?? '0';

    if (plataforma.toLowerCase() == 'whatsapp') {
      await compartirEnWhatsApp(
        context: context,
        offerId: offerId,
        offerName: offerName,
        descripcion: descripcion,
        presupuesto: presupuesto,
        imagenUrl: imagenUrl,
      );
    } else {
      // For other platforms use the generic method
      await compartirOferta(
        context: context,
        offerId: offerId,
        offerName: offerName,
        descripcion: descripcion,
        presupuesto: presupuesto,
        nombreUsuario: nombre,
        calificacion: rating,
        numResenas: reviews,
        imagenUrl: imagenUrl,
      );
    }
  }

  // Method to show internal chat selector
  static Future<void> mostrarSelectorChatsInternos({
    required BuildContext context,
    required Function(String chatId) onChatSelected,
    required String tituloSelector,
  }) async {
    // Here you would implement logic to show available chats
    // and call onChatSelected when the user chooses one

    // This is a simple example with dummy options
    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tituloSelector,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Replace these with your real chats from the database
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.chat)),
              title: const Text('Chat #1'),
              onTap: () {
                Navigator.pop(context);
                onChatSelected('chat_id_1');
              },
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.group)),
              title: const Text('Grupo #2'),
              onTap: () {
                Navigator.pop(context);
                onChatSelected('chat_id_2');
              },
            ),
          ],
        ),
      ),
    );
  }
}