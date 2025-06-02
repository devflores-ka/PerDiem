// Archivo: lib/widgets/tarjetas.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/review_service.dart';
import '../widgets/rating_display.dart'; // Importar el servicio de reseñas

final supabase = Supabase.instance.client;

// Formato de moneda
final numberFormat = NumberFormat.currency(
  locale: 'es_CL',
  symbol: '\$',
  decimalDigits: 0,
);

Future<List<TarjetaServicio>> obtenerTarjetasServicios() async {
  try {
    if (kDebugMode) {
      print('Iniciando obtención de ofertas...');
    }
    final ofertas = await supabase
        .schema('jobs')
        .from('offers')
        .select('image_url, description, amount, user_id');

    if (kDebugMode) {
      print('Ofertas obtenidas: ${ofertas.length}');
    }

    // ignore: omit_local_variable_types, prefer_final_locals
    List<TarjetaServicio> tarjetas = [];

    for (var oferta in ofertas) {
      if (kDebugMode) {
        print("Procesando oferta: ${oferta['description']}");
      }
      final String userId = oferta['user_id'];
      if (kDebugMode) {
        print('Buscando usuario con ID: $userId');
      }

      try {
        final usuarios = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl')
            .eq('id', userId);

        if (kDebugMode) {
          print('Usuarios encontrados: ${usuarios.length}');
        }

        if (usuarios.isNotEmpty) {
          final usuario = usuarios[0];
          if (kDebugMode) {
            print("Usando usuario: ${usuario['firstName']}");
          }

          // Obtener la calificación real del usuario
          final userRating = await ReviewService.getUserRatingOptimized(userId);

          tarjetas.add(TarjetaServicio(
            imagenUrl: oferta['image_url'],
            descripcion: oferta['description'],
            presupuesto: oferta['amount'],
            nombreUsuario: '${usuario['firstName']} ${usuario['lastName']}',
            avatarUrl: usuario['imageUrl'],
            calificacion: userRating.averageRating,
            numResenas: userRating.totalReviews.toString(),
            esFavorito: false,
          ),
          );
        } else {
          if (kDebugMode) {
            print('No se encontró usuario con ID: $userId');
          }
        }
      } catch (userError) {
        if (kDebugMode) {
          print('Error al buscar usuario con ID $userId: $userError');
        }
      }
    }

    if (kDebugMode) {
      print('Total de tarjetas creadas: ${tarjetas.length}');
    }
    return tarjetas;

  } catch (e) {
    if (kDebugMode) {
      print('Error principal: $e');
    }
    throw Exception('Error al obtener datos: $e');
  }
}

class TarjetaServicio extends StatelessWidget {

  final String imagenUrl;
  final String nombreUsuario;
  final String avatarUrl;
  final String descripcion;
  final double calificacion;
  final String numResenas;
  final double presupuesto;
  final bool esFavorito;

  const TarjetaServicio({
    super.key,
    required this.imagenUrl,
    required this.nombreUsuario,
    required this.avatarUrl,
    required this.descripcion,
    required this.calificacion,
    required this.numResenas,
    required this.presupuesto,
    this.esFavorito = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.grey[100],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 3,
    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen del servicio
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imagenUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('Error loading image: $error');
                }
                return Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Usuario y botón de favorito
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    nombreUsuario,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Icon(
                esFavorito ? Icons.favorite : Icons.favorite_border,
                color: esFavorito ? Colors.red : Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: 5),

          // Descripción
          Text(
            descripcion,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 5),

          // Calificación y presupuesto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RatingDisplay(
                rating: calificacion,
                reviewCount: int.tryParse(numResenas) ?? 0,
                iconSize: 18,
                showEmpty: false, // Ocultar si no hay reseñas
              ),
              Text(
                '${numberFormat.format(presupuesto)} CLP',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// tarjetas.dart - Versión compacta de TarjetaServicio
class TarjetaServicioCompacta extends StatelessWidget {
  final String imagenUrl;
  final String nombreUsuario;
  final String avatarUrl;
  final String descripcion;
  final double calificacion;
  final String numResenas;
  final double presupuesto;
  final bool esFavorito;

  const TarjetaServicioCompacta({
    super.key,
    required this.imagenUrl,
    required this.nombreUsuario,
    required this.avatarUrl,
    required this.descripcion,
    required this.calificacion,
    required this.numResenas,
    required this.presupuesto,
    this.esFavorito = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.grey[100],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagen estandarizada
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: SizedBox(
            height: 120, // Altura fija para estandarizar
            width: double.infinity,
            child: Image.network(
              imagenUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('Error loading image: $error');
                }
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 40,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),

        // Contenido de la tarjeta
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Usuario y favorito
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                    radius: 12,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nombreUsuario,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    esFavorito ? Icons.favorite : Icons.favorite_border,
                    color: esFavorito ? Colors.red : Colors.grey,
                    size: 16,
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Descripción
              Text(
                descripcion,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // Precio y calificación
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Calificación compacta
                  if (calificacion > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          calificacion.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '($numResenas)',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                  // Precio abreviado
                  Text(
                    presupuesto >= 1000
                        ? '\$${(presupuesto / 1000).toStringAsFixed(0)}k'
                        : numberFormat.format(presupuesto),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Widget para banners publicitarios
class AdBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final IconData? icon;

  const AdBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    height: 80,
    decoration: BoxDecoration(
      color: backgroundColor ?? Colors.blue[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue[200]!, width: 1),
    ),
    child: Row(
      children: [
        // Icono del anuncio
        Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon ?? Icons.campaign,
            color: Colors.blue,
            size: 30,
          ),
        ),

        // Contenido del anuncio
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Botón CTA
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(60, 30),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}