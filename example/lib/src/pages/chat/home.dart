import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth.dart';
import 'rooms.dart';
import 'users.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _error = false;
  bool _initialized = false;
  User? _user;

  @override
  void initState() {
    initializeSupabase();
    super.initState();
  }

  void initializeSupabase() async {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        setState(() {
          _user = data.session?.user;
        });
      });
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container();
    }

    if (!_initialized) {
      return Container();
    }

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('Mensajes'),
        // Eliminar el botón de regreso del AppBar cuando se muestra dentro del flujo principal
        automaticallyImplyLeading: false,
        actions: _user != null ? [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UsersPage(),
                ),
              );
            },
            child: Text(
              'Nuevo chat',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ] : null,
        backgroundColor: Colors.blue,
      ),
      backgroundColor: Colors.white,
      body: _user == null
          ? Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(
          bottom: 200,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No haz iniciado sesión'),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (context) => const AuthScreen(),
                  ),
                );
              },
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Envolver RoomsPage en un Expanded para que ocupe todo el espacio disponible
          Expanded(
            child: RoomsPage(),
          ),
        ],
      ),
    );
  }
}

// Asegúrate de importar UsersPage si no está importado
// import 'users.dart';