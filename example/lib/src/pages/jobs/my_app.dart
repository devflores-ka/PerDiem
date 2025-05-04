import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tarjetas.dart';
import '../../widgets/vista_tarjeta.dart';
import '../auth/auth.dart';
import 'formulario_trabajo.dart'; // Pantalla para publicar servicio

class TrabajoPage extends StatefulWidget {
  const TrabajoPage({super.key});

  @override
  State<TrabajoPage> createState() => _TrabajoPageState();
}

class _TrabajoPageState extends State<TrabajoPage> {
  final supabase = Supabase.instance.client;
  User? _user;
  List<TarjetaServicio> _tarjetas = [];
  List<Map<String, double>> _coordenadas = [];
  bool _cargando = true;
  List<String> _ids = [];
  List<String> _names = [];

  @override
  void initState() {
    super.initState();
    _verificarSesion();
    _cargarTarjetas();
  }

  /// Verifica si hay un usuario autenticado
  void _verificarSesion() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {
        _user = data.session?.user;
      });
    });
  }

  /// Obtiene las ofertas desde Supabase
  Future<void> _cargarTarjetas() async {
    setState(() => _cargando = true);

    try {
      final ofertas = await supabase
          .schema('jobs')
          .from('offers')
          .select('id, name, image_url, description, amount, user_id, latitud, longitud');

      final tarjetas = <TarjetaServicio>[];
      final coordenadas = <Map<String, double>>[];

      final ids = <String>[];   // o <int>[] si prefieres mantener el tipo original
      final names = <String>[];

      for (var oferta in ofertas) {
        try {
          final dynamic userId = oferta['user_id'];
          
          // Extraer coordenadas ya procesadas por PostGIS
          double latitud = oferta['latitud'] ?? 0.0;
          double longitud = oferta['longitud'] ?? 0.0;
          
          // **Extraer coordenadas desde Supabase**
          final String? location = oferta['location'];
          if (location != null) {
            final Map<String, dynamic> geojson = jsonDecode(location);
            if (geojson.containsKey('coordinates')) {
              longitud = geojson['coordinates'][0];
              latitud = geojson['coordinates'][1];
            }
          }



          // Manejar correctamente el campo amount
          final dynamic amount = oferta['amount'];
          int presupuesto;
          if (amount is num) {
            presupuesto = amount.toInt();
          } else {
            presupuesto = int.tryParse(amount.toString()) ?? 0;
          }

          var imageUrl = oferta['image_url']?.toString() ?? '';
          if (imageUrl.isEmpty) {
            imageUrl = 'https://placehold.co/150';
          }

          try {
            final usuarios = await supabase
                .schema('chats')
                .from('users')
                .select('firstName, lastName, imageUrl')
                .eq('id', userId.toString());

            if (usuarios.isNotEmpty) {
              final usuario = usuarios[0];
              var avatarUrl = usuario['imageUrl']?.toString() ?? '';
              if (avatarUrl.isEmpty) {
                avatarUrl = 'https://placehold.co/40';
              }

              tarjetas.add(TarjetaServicio(
                imagenUrl: imageUrl,
                descripcion: oferta['description'] ?? '',
                presupuesto: presupuesto,
                nombreUsuario: '${usuario['firstName'] ?? ''} ${usuario['lastName'] ?? ''}',
                avatarUrl: avatarUrl,
                calificacion: 4.9,
                numResenas: '2.5k',
                esFavorito: false,
              ),
              );

              coordenadas.add({'latitud': latitud, 'longitud': longitud});
              ids.add(oferta['id'].toString());
              names.add(oferta['name']?.toString() ?? '');

            }
          } catch (queryError) {
            if (kDebugMode) {
              print('Error en consulta de usuario: $queryError');
            }
          }
        } catch (userError) {
          if (kDebugMode) {
            print('Error al obtener usuario: $userError');
          }
        }
      }

      if (mounted) {
        setState(() {
          _tarjetas = tarjetas;
          _coordenadas = coordenadas;
          _ids = ids;
          _names = names;
          _cargando = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar tarjetas: $e');
      }
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  /// Redirige al formulario o autenticación
  void _manejarBotonFlotante() {
    if (_user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormularioTrabajo()),
      ).then((_) => _cargarTarjetas());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          onRefresh: _cargarTarjetas,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _tarjetas.isEmpty
                    ? const Center(child: Text('No hay ofertas disponibles'))
                    : ListView.builder(
                        itemCount: _tarjetas.length,
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetalleOferta(
                                  imagenUrl: _tarjetas[index].imagenUrl,
                                  descripcion: _tarjetas[index].descripcion,
                                  presupuesto: _tarjetas[index].presupuesto,
                                  nombreUsuario: _tarjetas[index].nombreUsuario,
                                  avatarUrl: _tarjetas[index].avatarUrl,
                                  calificacion: _tarjetas[index].calificacion,
                                  numResenas: _tarjetas[index].numResenas,
                                  latitud: _coordenadas[index]['latitud']!,
                                  longitud: _coordenadas[index]['longitud']!,
                                  offerId: _ids[index],
                                  offerName: _names[index],

                                ),
                              ),
                            );
                          },
                          child: _tarjetas[index],
                        ),
                      ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _manejarBotonFlotante,
          tooltip: 'Publicar servicio',
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
}
