// ignore_for_file: prefer_expression_function_bodies

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:perdiem_app/flutter_supabase_chat_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
// ignore: depend_on_referenced_packages
import 'l10n/generated/app_localizations.dart';
import 'src/managers/language_provider.dart';
import 'src/pages/chat/home.dart';
import 'src/pages/jobs/my_app.dart';
import 'src/pages/resumen/negotiations_screen.dart';
import 'src/pages/search/map_screen.dart';
import 'src/pages/user/perfil_screen.dart';
import 'src/pages/verificacion/verificacion_screen.dart';
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

  runApp(
    // ✅ Envolvemos la app en MultiProvider para inyectar el idioma
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Escuchamos el idioma actual
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      title: 'PerDiem', // Nombre de tu app
      debugShowCheckedModeBanner: false,

      // ✅ CONFIGURACIÓN DE IDIOMAS (Aquí ocurre la magia)
      locale: languageProvider.locale, // Usa el idioma del Provider
      localizationsDelegates: const [
        AppLocalizations.delegate, // El delegado generado por tus archivos .arb
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'), // Español
        Locale('en'), // Inglés
      ],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87, // Títulos e íconos oscuros
          surfaceTintColor: Colors.transparent, // Evita que se tiña de colores raros al hacer scroll
          elevation: 0, // Plano por defecto
          scrolledUnderElevation: 4, // El efecto: Sombra que aparece al hacer scroll
          shadowColor: Colors.black, // Color de la sombra
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.dark, // Batería y Wi-Fi en color oscuro
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/main': (context) => const UserOnlineStateObserver(
          child: MainScreen(),
        ),
      },
    );
  }
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
    const VerificationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // ✅ TRADUCCIÓN DEL MENÚ INFERIOR
    // Usamos AppLocalizations.of(context)! para obtener los textos
    // Nota: Necesitas definir estas claves en tus archivos .arb (bottomNavHome, etc.)
    // Si aún no las tienes, usa texto duro temporalmente o define las keys.
    
    // Ejemplo de cómo se vería con traducción real:
    // final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: _paginas[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        items: const [
          // TODO: Reemplazar strings duros con l10n.home, l10n.search, etc. cuando actualices los .arb
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Búsqueda'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Trabajos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}