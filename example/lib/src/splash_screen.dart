import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🟢 Agregamos esto para poder usar kIsWeb

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Esperar un poco para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));

    // Navegar a la pantalla correspondiente
    if (mounted) {
      // 🟢 NUEVO: Revisamos si estamos en la web y en el link específico
      if (kIsWeb && Uri.base.path == '/borrar-cuenta') {
        // Los mandamos a la pantalla de borrar cuenta
        Navigator.of(context).pushReplacementNamed('/borrar-cuenta');
      } else {
        // Flujo normal: Navegar a la pantalla principal
        Navigator.of(context).pushReplacementNamed('/main');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 250,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ],
        ),
      ),
    );
}