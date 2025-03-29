import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<List<TarjetaServicio>> obtenerTarjetasServicios() async {
  try {
    print("Iniciando obtención de ofertas...");
    final ofertas = await supabase
        .schema('jobs')
        .from('offers')
        .select('image_url, description, amount, user_id');
    
    print("Ofertas obtenidas: ${ofertas.length}");
    
    List<TarjetaServicio> tarjetas = [];
    
    for (var oferta in ofertas) {
      print("Procesando oferta: ${oferta['description']}");
      String userId = oferta['user_id'];
      print("Buscando usuario con ID: $userId");
      
      try {
        final usuarios = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl')
            .eq('id', userId);
        
        print("Usuarios encontrados: ${usuarios.length}");
        
        if (usuarios.isNotEmpty) {
          var usuario = usuarios[0];
          print("Usando usuario: ${usuario['firstName']}");
          
          tarjetas.add(TarjetaServicio(
            imagenUrl: oferta['image_url'],
            descripcion: oferta['description'],
            presupuesto: oferta['amount'],
            nombreUsuario: '${usuario['firstName']} ${usuario['lastName']}',
            avatarUrl: usuario['imageUrl'],
            calificacion: 4.9,
            numResenas: '2.5k',
            esFavorito: false,
          ));
        } else {
          print("No se encontró usuario con ID: $userId");
        }
      } catch (userError) {
        print("Error al buscar usuario con ID $userId: $userError");
      }
    }
    
    print("Total de tarjetas creadas: ${tarjetas.length}");
    return tarjetas;
    
  } catch (e) {
    print("Error principal: $e");
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
  final int presupuesto;
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
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    Text(
                      ' $calificacion ($numResenas)',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        ),
                    ),
                  ],
                ),
                Text(
                  '\$$presupuesto CLP',
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
