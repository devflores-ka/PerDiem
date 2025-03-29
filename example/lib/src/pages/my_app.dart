import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tarjetas.dart';
import 'auth.dart';
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
  bool _cargando = true;

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
/// Obtiene las ofertas desde Supabase
Future<void> _cargarTarjetas() async {
  setState(() => _cargando = true);

  try {
    // 1. Obtener ofertas sin relaciones
    final ofertas = await supabase
        .schema('jobs')
        .from('offers')
        .select('image_url, description, amount, user_id');
    
    // Lista para almacenar los resultados finales
    List<TarjetaServicio> tarjetas = [];
    
// 2. Para cada oferta, obtener información del usuario
for (var oferta in ofertas) {
  try {
    final dynamic userId = oferta['user_id'];

    if (kDebugMode) {
        print('Tipo de user_id: ${userId.runtimeType}, valor: $userId');
    }

    // Inspeccionar la estructura completa de la oferta
    if (kDebugMode) {
        print('Estructura completa de oferta: $oferta');
    }

    // Manejar correctamente el campo amount
    dynamic amount = oferta['amount'];
    int presupuesto;
    if (amount is double) {
        presupuesto = amount.toInt();
    } else if (amount is int) {
        presupuesto = amount;
    } else {
        presupuesto = int.tryParse(amount.toString()) ?? 0;
    }
    
    // Verificar que la URL de la imagen no sea nula o vacía
    String imageUrl = oferta['image_url']?.toString() ?? '';
    // Si la URL está vacía, usar una imagen por defecto
    if (imageUrl.isEmpty) {
        imageUrl = 'https://placehold.co/150'; // Usando placehold.co en lugar de via.placeholder.com
    }
    
    if (imageUrl.contains('supabase.co') && kDebugMode) {
        print('Trying to load Supabase image: $imageUrl');
    }
    
    try {
        final usuarios = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl')
            .eq('id', userId.toString());
            
        if (kDebugMode) {
            print('Consulta exitosa, resultados: ${usuarios.length}');
        }
    
        if (usuarios.isNotEmpty) {
          var usuario = usuarios[0];
          
          // Verificar la URL del avatar
          String avatarUrl = usuario['imageUrl']?.toString() ?? '';
          if (avatarUrl.isEmpty) {
              avatarUrl = 'https://placehold.co/40'; // Usando placehold.co en lugar de via.placeholder.com
          }

          tarjetas.add(TarjetaServicio(
            imagenUrl: imageUrl,
            descripcion: oferta['description'] ?? '',
            presupuesto: presupuesto,
            nombreUsuario: '${usuario['firstName'] ?? ''} ${usuario['lastName'] ?? ''}',
            avatarUrl: avatarUrl,
            calificacion: 4.9, // Temporal
            numResenas: '2.5k', // Temporal
            esFavorito: false,
          ));
        }
    } catch (queryError) {
        print("Error específico en la consulta: $queryError");
        print("Detalles adicionales: ${queryError.runtimeType}");
    }
  } catch (userError) {
    print("Error al obtener usuario: $userError");
  }
}
    
    if (mounted) {
      setState(() {
        _tarjetas = tarjetas;
        _cargando = false;
      });
    }
  } catch (e) {
    print("Error al cargar tarjetas: $e");
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
      ).then((_) => _cargarTarjetas()); // Recarga después de publicar
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
                        itemBuilder: (context, index) => _tarjetas[index],
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
