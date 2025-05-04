import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'src/pages/chat/home.dart';
import 'src/pages/jobs/my_app.dart';
import 'src/pages/map_example.dart';
import 'src/pages/search/location_example.dart';
import 'src/pages/user/perfil_screen.dart';
import 'src/theme/color_schemes.dart';
import 'src/widgets/notification_service.dart';
import 'supabase_options.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseOptions.url,
    anonKey: supabaseOptions.anonKey,
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize the notification service
  await NotificationService().initialize();
  if (kDebugMode) {
    print('🚀 Initializing NotificationService');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        title: 'Supabase Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightColorScheme,
          scaffoldBackgroundColor: Colors.white,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkColorScheme,
        ),
        themeMode: ThemeMode.dark,
        home: const UserOnlineStateObserver(
          child: MainScreen(),
        ),
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
    const UbicacionActual(),
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
