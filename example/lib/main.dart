import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // <- AGREGAR ESTA LÍNEA
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'src/pages/chat/home.dart';
import 'src/pages/jobs/my_app.dart';
import 'src/pages/resumen/negotiations_screen.dart';
import 'src/pages/search/map_screen.dart';
import 'src/pages/user/perfil_screen.dart';
import 'src/services/notification_service.dart';
import 'src/splash_screen.dart';
import 'src/theme/color_schemes.dart';
import 'supabase_options.dart';

// Clave global para ScaffoldMessenger
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Clave global para el navegador
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: supabaseOptions.url,
    anonKey: supabaseOptions.anonKey,
  );

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar el servicio de notificaciones
  await NotificationService().initialize();
  if (kDebugMode) {
    print('🚀 Initializing NotificationService');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: scaffoldMessengerKey,
    navigatorKey: navigatorKey,
    title: 'Supabase Chat',
    debugShowCheckedModeBanner: false,

    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('es', 'ES'),
      Locale('en', 'US'),
    ],
    locale: const Locale('es', 'ES'),

    theme: ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: Colors.white,
    ),

    // Usar initialRoute en lugar de home
    initialRoute: '/',
    routes: {
      '/': (context) => const SplashScreen(),
      '/main': (context) => const UserOnlineStateObserver(
        child: MainScreen(),
      ),
    },
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _paginas = [
    const TrabajoPage(),
    MapScreen(),
    const HomePage(),
    const NegotiationsScreen(),
    const PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _paginas[_selectedIndex],
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey[400],
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Búsqueda'),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Mensajes'),
        BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Trabajos'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    ),
  );
}