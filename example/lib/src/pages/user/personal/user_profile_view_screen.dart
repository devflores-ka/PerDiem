import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/review_service.dart';
import '../../../widgets/user_offers_widget.dart';
import '../../chat/room.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String? userName; // Para mostrar en el AppBar mientras carga
  final String? userImageUrl;    // NUEVO
  final String? userDescription; // NUEVO
  final double? userLatitude;    // NUEVO
  final double? userLongitude;   // NUEVO

  const UserProfileViewScreen({
    super.key,
    required this.userId,
    this.userName,
    this.userImageUrl,      // NUEVO
    this.userDescription,   // NUEVO
    this.userLatitude,      // NUEVO
    this.userLongitude,     // NUEVO
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final supabase = Supabase.instance.client;

  // Estado de carga
  bool isLoading = true;

  // Chat
  types.User? chatUser;
  bool isLoadingChatUser = false;

  // Datos del usuario
  String firstName = '';
  String lastName = '';
  String imageUrl = 'https://placehold.co/100';
  String descripcion = 'Sin descripción';

  // Calificaciones
  double averageRating = 0.0;
  int totalReviews = 0;
  bool isLoadingReviews = true;
  UserRating? userRating;

  // Habilidades
  List<Map<String, dynamic>> userSkills = [];

  // Categorías y oficios
  List<Map<String, dynamic>> userCategories = [];
  Map<int, List<Map<String, dynamic>>> userOficios = {};

  // Ubicación
  String currentLocationAddress = 'Ubicación no disponible';
  bool isLoadingLocation = true;

  @override
    void initState() {
      super.initState();
      debugPrint('🚀 UserProfileViewScreen iniciado para usuario: ${widget.userId}');
      debugPrint('🚀 Nombre temporal: ${widget.userName}');
      _initializeData();
    }

  Future<void> _initializeData() async {
    debugPrint('🔄 Iniciando carga de datos...');
    await _cargarDatosUsuario();
    if (mounted) {
      debugPrint('🔄 Cargando datos adicionales...');
      await Future.wait([
        _cargarHabilidadesUsuario(),
        _cargarCalificacionUsuario(),
        _loadUserCategoriesAndOficios(),
        _loadUserLocation(),
        // QUITAR _loadChatUser() de aquí
      ]);
      debugPrint('✅ Todos los datos cargados');
    }
  }

  Future<void> _cargarDatosUsuario() async {
    setState(() => isLoading = true);

    try {
      debugPrint('🔍 Cargando datos con RPC para usuario: ${widget.userId}');

      // Intentar la RPC primero
      final result = await supabase.rpc('get_user_profile', params: {
        'target_user_id': widget.userId,
      },);

      debugPrint('🔍 Resultado RPC get_user_profile: $result');

      if (result != null && result is List && result.isNotEmpty) {
        final userData = result[0] as Map<String, dynamic>;

        setState(() {
          firstName = userData['firstName'] ?? '';
          lastName = userData['lastName'] ?? '';
          imageUrl = userData['imageUrl'] ?? 'https://placehold.co/100';
          descripcion = userData['descripcion'] ?? 'Sin descripción';
          isLoading = false;
        });

        debugPrint('✅ Datos cargados desde RPC: $firstName $lastName');

      } else {
        debugPrint('❌ RPC vacía, usando datos del mapa...');

        // USAR DATOS DEL MAPA (que sí funcionan)
        setState(() {
          // Nombres del mapa
          if (widget.userName != null) {
            final nameParts = widget.userName!.split(' ');
            firstName = nameParts.first;
            lastName = nameParts.skip(1).join(' ');
          } else {
            firstName = 'Usuario';
            lastName = '';
          }

          // IMAGEN DEL MAPA (¡aquí está la clave!)
          imageUrl = widget.userImageUrl ?? 'https://placehold.co/100';

          // DESCRIPCIÓN DEL MAPA
          descripcion = widget.userDescription ?? 'Sin descripción disponible';

          isLoading = false;
        });

        debugPrint('✅ Usando datos del mapa:');
        debugPrint('   - Nombre: $firstName $lastName');
        debugPrint('   - Imagen: $imageUrl');
        debugPrint('   - Descripción: $descripcion');

        // Si tenemos coordenadas del mapa, usarlas también
        if (widget.userLatitude != null && widget.userLongitude != null) {
          await _updateLocationFromMap(widget.userLatitude!, widget.userLongitude!);
        }
      }
    } catch (e) {
      debugPrint('❌ Error al llamar RPC: $e');

      // FALLBACK CON DATOS DEL MAPA
      setState(() {
        firstName = widget.userName?.split(' ').first ?? 'Error';
        lastName = widget.userName?.split(' ').skip(1).join(' ') ?? '';
        imageUrl = widget.userImageUrl ?? 'https://placehold.co/100';
        descripcion = widget.userDescription ?? 'Error al cargar datos';
        isLoading = false;
      });
    }
  }

  Future<void> _loadChatUser() async {
    if (!mounted) return;
    setState(() => isLoadingChatUser = true);

    try {
      debugPrint('🔍 Buscando usuario para chat: ${widget.userId}');

      // Obtener TODOS los usuarios del chat
      final users = await SupabaseChatCore.instance.users();

      debugPrint('🔍 Total usuarios de chat encontrados: ${users.length}');

      // Buscar por ID exacto
      final targetUser = users.where((user) => user.id == widget.userId).toList();

      if (targetUser.isNotEmpty) {
        debugPrint('✅ Usuario encontrado en chat: ${targetUser.first.firstName}');
        if (mounted) {
          setState(() {
            chatUser = targetUser.first;
            isLoadingChatUser = false;
          });
        }
      } else {
        debugPrint('❌ Usuario no existe en chat, creándolo...');

        // Crear el usuario en el sistema de chat
        await _createChatUser();
      }
    } catch (e) {
      debugPrint('❌ Error loading chat user: $e');
      if (mounted) {
        setState(() => isLoadingChatUser = false);
      }
    }
  }

  Future<void> _createChatUser() async {
    try {
      debugPrint('🔧 Creando usuario en sistema de chat...');

      // Usar timestamp en milisegundos (bigint)
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insertar el usuario en la tabla de usuarios del chat (esquema chats)
      await supabase
          .schema('chats')
          .from('users').upsert({
        'id': widget.userId,
        'firstName': firstName.isNotEmpty ? firstName : widget.userName?.split(' ').first ?? 'Usuario',
        'lastName': lastName.isNotEmpty ? lastName : widget.userName?.split(' ').skip(1).join(' ') ?? '',
        'imageUrl': imageUrl != 'https://placehold.co/100' ? imageUrl : widget.userImageUrl,
        'createdAt': now,
        'updatedAt': now,
      });

      debugPrint('✅ Usuario insertado en sistema de chat');

      // Esperar un poco para que se propague
      await Future.delayed(const Duration(milliseconds: 500));

      // Verificar que el usuario ahora existe
      final users = await SupabaseChatCore.instance.users();
      final verifyUser = users.where((user) => user.id == widget.userId).toList();

      debugPrint('🔍 Verificación: usuario existe después de crear: ${verifyUser.isNotEmpty}');

      if (verifyUser.isNotEmpty) {
        debugPrint('✅ Usuario verificado en chat: ${verifyUser.first.firstName}');

        if (mounted) {
          setState(() {
            chatUser = verifyUser.first;
            isLoadingChatUser = false;
          });
        }
      } else {
        // Si aún no aparece, crear objeto directamente
        debugPrint('⚠️ Usuario no aparece en core, creando objeto directo...');

        final createdUser = types.User(
          id: widget.userId,
          firstName: firstName.isNotEmpty ? firstName : widget.userName?.split(' ').first,
          lastName: lastName.isNotEmpty ? lastName : widget.userName?.split(' ').skip(1).join(' '),
          imageUrl: imageUrl != 'https://placehold.co/100' ? imageUrl : widget.userImageUrl,
        );

        if (mounted) {
          setState(() {
            chatUser = createdUser;
            isLoadingChatUser = false;
          });
        }
      }

      debugPrint('✅ Usuario listo para chat');

    } catch (e) {
      debugPrint('❌ Error creando usuario en chat: $e');

      // Fallback: crear usuario directamente
      debugPrint('🔧 Fallback: creando usuario directamente...');

      final createdUser = types.User(
        id: widget.userId,
        firstName: firstName.isNotEmpty ? firstName : widget.userName?.split(' ').first,
        lastName: lastName.isNotEmpty ? lastName : widget.userName?.split(' ').skip(1).join(' '),
        imageUrl: imageUrl != 'https://placehold.co/100' ? imageUrl : widget.userImageUrl,
      );

      if (mounted) {
        setState(() {
          chatUser = createdUser;
          isLoadingChatUser = false;
        });
      }
    }
  }

  Future<void> _updateLocationFromMap(double lat, double lng) async {
    try {
      setState(() => isLoadingLocation = true);

      debugPrint('🗺️ Actualizando ubicación desde datos del mapa: $lat, $lng');

      final address = await _getAddressFromCoordinates(lat, lng);

      setState(() {
        currentLocationAddress = address;
        isLoadingLocation = false;
      });

      debugPrint('✅ Ubicación actualizada desde mapa: $address');
    } catch (e) {
      debugPrint('❌ Error actualizando ubicación desde mapa: $e');
      setState(() {
        currentLocationAddress = 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _cargarHabilidadesUsuario() async {
    try {
      final data = await supabase
          .schema('jobs')
          .from('habilidades_usuario')
          .select('habilidad_id, nivel, habilidades:habilidad_id(id, name)')
          .eq('user_id', widget.userId);

      final skills = <Map<String, dynamic>>[];
      for (var item in data) {
        if (item['habilidades'] != null) {
          skills.add({
            'id': item['habilidad_id'],
            'name': item['habilidades']['name'],
            'nivel': item['nivel'] ?? 'Intermedio',
          });
        }
      }

      setState(() => userSkills = skills);
    } catch (e) {
      debugPrint('Error al cargar habilidades del usuario: $e');
    }
  }

  Future<void> _cargarCalificacionUsuario() async {
    try {
      final rating = await ReviewService.getUserRatingOptimized(widget.userId);

      setState(() {
        userRating = rating;
        averageRating = rating.averageRating;
        totalReviews = rating.totalReviews;
        isLoadingReviews = false;
      });
    } catch (e) {
      debugPrint('Error al cargar calificación del usuario: $e');
      setState(() => isLoadingReviews = false);
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      // Usando la API de Nominatim (OpenStreetMap) - es gratuita
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=es';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'TuApp/1.0', // Requerido por Nominatim
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['address'] != null) {
          final address = data['address'];

          // Extraer información relevante
          final String city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              'Ciudad desconocida';

          final String region = address['state'] ??
              address['region'] ??
              'Región desconocida';

          final String country = address['country'] ?? 'País desconocido';

          return '$city, $region, $country';
        }
      }

      // Si falla, devolver coordenadas como respaldo
      return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';

    } catch (e) {
      debugPrint('Error en geocodificación: $e');
      return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
    }
  }

  Future<void> _loadUserLocation() async {
    // Si ya tenemos ubicación desde el mapa, no hacer consulta adicional
    if (currentLocationAddress != 'Ubicación no disponible' && !isLoadingLocation) {
      debugPrint('🗺️ Ubicación ya cargada desde mapa, saltando consulta DB');
      return;
    }

    setState(() => isLoadingLocation = true);

    try {
      final locationData = await supabase
          .schema('jobs')
          .from('worker_locations')
          .select('latitud, longitud')
          .eq('user_id', widget.userId)
          .eq('user_type', 'worker')
          .maybeSingle();

      if (locationData != null) {
        final lat = locationData['latitud'] is String
            ? double.parse(locationData['latitud'])
            : locationData['latitud'].toDouble();
        final lng = locationData['longitud'] is String
            ? double.parse(locationData['longitud'])
            : locationData['longitud'].toDouble();

        final address = await _getAddressFromCoordinates(lat, lng);

        setState(() {
          currentLocationAddress = address;
          isLoadingLocation = false;
        });
      } else {
        setState(() {
          currentLocationAddress = 'Ubicación no configurada';
          isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ubicación: $e');
      setState(() {
        currentLocationAddress = 'Error al cargar ubicación';
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadUserCategoriesAndOficios() async {
    try {
      // Cargar categorías del usuario específico
      final categoriesData = await supabase
          .schema('jobs')
          .from('user_categories')
          .select('category_id, categories:category_id(id, name)')
          .eq('user_id', widget.userId);

      final categories = <Map<String, dynamic>>[];
      final oficiosPorCategoria = <int, List<Map<String, dynamic>>>{};

      for (var item in categoriesData) {
        if (item['categories'] != null) {
          final categoryData = item['categories'];
          categories.add({
            'id': categoryData['id'],
            'name': categoryData['name'],
          });

          // Cargar oficios para esta categoría
          final oficiosData = await supabase
              .schema('jobs')
              .from('user_oficios')
              .select('oficio_id, oficios:oficio_id(id, name)')
              .eq('user_id', widget.userId)
              .eq('category_id', categoryData['id']);

          final oficios = <Map<String, dynamic>>[];
          for (var oficioItem in oficiosData) {
            if (oficioItem['oficios'] != null) {
              oficios.add({
                'id': oficioItem['oficios']['id'],
                'name': oficioItem['oficios']['name'],
              });
            }
          }

          oficiosPorCategoria[categoryData['id']] = oficios;
        }
      }

      setState(() {
        userCategories = categories;
        userOficios = oficiosPorCategoria;
      });
    } catch (e) {
      debugPrint('Error loading categories and oficios: $e');
    }
  }

  void _handleChatPressed() async {
    debugPrint('🚀 Iniciando chat...');

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No hay usuario autenticado');
        return;
      }

      debugPrint('🔍 Usuario actual: ${currentUser.id}');
      debugPrint('🔍 Usuario objetivo: ${widget.userId}');

      // PASO 1: CRÍTICO - Asegurar que AMBOS usuarios existan en chats.users
      await _ensureCurrentUserExists(currentUser.id);
      await _ensureTargetUserExists();

      // PASO 2: Buscar room existente
      final existingRoomId = await _findExistingRoomInDB(currentUser.id, widget.userId);

      if (existingRoomId != null) {
        debugPrint('✅ Room existente encontrada: $existingRoomId');

        // Cargar room de forma segura
        final room = await _loadExistingRoomSafely(existingRoomId);

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RoomPage(room: room)),
          );
        }
        return;
      }

      // PASO 3: Crear nueva room
      final room = await _createNewRoomSafely(currentUser.id);

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RoomPage(room: room)),
        );
      }

    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // MÉTODO MEJORADO para asegurar que el usuario objetivo existe
  Future<void> _ensureTargetUserExists() async {
    try {
      debugPrint('🔍 Verificando usuario objetivo en chat: ${widget.userId}');

      // Verificar si existe en chats.users
      final existingUser = await supabase
          .schema('chats')
          .from('users')
          .select('id, firstName, lastName, imageUrl')
          .eq('id', widget.userId)
          .maybeSingle();

      if (existingUser == null) {
        debugPrint('🔧 Usuario objetivo no existe en chat, creándolo...');

        // Obtener datos completos del usuario desde chats.users
        final profileData = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl')
            .eq('id', widget.userId)
            .maybeSingle();

        var targetFirstName = 'Usuario';
        var targetLastName = '';
        String? targetImageUrl;

        if (profileData != null) {
          targetFirstName = profileData['firstName'] ?? 'Usuario';
          targetLastName = profileData['lastName'] ?? '';
          targetImageUrl = profileData['imageUrl'];
        } else {
          // Si no hay datos en users, usar los datos que ya tenemos
          targetFirstName = firstName.isNotEmpty ? firstName : (widget.userName?.split(' ').first ?? 'Usuario');
          targetLastName = lastName.isNotEmpty ? lastName : (widget.userName?.split(' ').skip(1).join(' ') ?? '');
          targetImageUrl = (imageUrl != 'https://placehold.co/100') ? imageUrl : widget.userImageUrl;
        }

        final now = DateTime.now().millisecondsSinceEpoch;

        // Intentar insertar el usuario (usando RPC si es necesario para evitar RLS)
        try {
          await supabase.rpc('create_chat_user_for_others', params: {
            'target_user_id': widget.userId,
            'first_name': targetFirstName,
            'last_name': targetLastName,
            'image_url': targetImageUrl,
          });

          debugPrint('✅ Usuario objetivo creado vía RPC: $targetFirstName $targetLastName');

        } catch (rpcError) {
          debugPrint('❌ Error con RPC: $rpcError');

          // Fallback: inserción directa
          try {
            await supabase
                .schema('chats')
                .from('users')
                .insert({
              'id': widget.userId,
              'firstName': targetFirstName,
              'lastName': targetLastName,
              'imageUrl': targetImageUrl,
              'createdAt': now,
              'updatedAt': now,
            });

            debugPrint('✅ Usuario objetivo creado por inserción directa');

          } catch (insertError) {
            debugPrint('❌ Error en inserción directa: $insertError');
            throw Exception('No se pudo crear el usuario en el chat');
          }
        }

        // Verificar que se creó correctamente
        await Future.delayed(const Duration(milliseconds: 500));

        final verifyUser = await supabase
            .schema('chats')
            .from('users')
            .select('*')
            .eq('id', widget.userId)
            .maybeSingle();

        if (verifyUser != null) {
          debugPrint('✅ Verificación exitosa: Usuario creado en chats.users');
        } else {
          debugPrint('❌ ADVERTENCIA: Usuario no aparece después de creación');
        }

      } else {
        debugPrint('✅ Usuario objetivo ya existe en chat: ${existingUser['firstName']} ${existingUser['lastName']}');
      }
    } catch (e) {
      debugPrint('❌ Error crítico verificando usuario objetivo: $e');
      throw Exception('Error al verificar usuario: $e');
    }
  }

  // MÉTODO MEJORADO para cargar room existente de forma segura
  Future<types.Room> _loadExistingRoomSafely(int roomId) async {
    try {
      debugPrint('🔍 Cargando room existente: $roomId');

      // Primero intentar desde SupabaseChatCore
      final rooms = await SupabaseChatCore.instance.rooms();
      final roomMatch = rooms.where((r) => r.id == roomId.toString()).toList();

      if (roomMatch.isNotEmpty) {
        final room = roomMatch.first;

        // Verificar que la room tiene ambos usuarios
        if (room.users.length >= 2) {
          debugPrint('✅ Room cargada correctamente con ${room.users.length} usuarios');
          return room;
        } else {
          debugPrint('⚠️ Room tiene solo ${room.users.length} usuarios, reconstruyendo...');
        }
      } else {
        debugPrint('⚠️ Room no encontrada en SupabaseChatCore, reconstruyendo...');
      }

      // Si llegamos aquí, necesitamos reconstruir la room
      return await _reconstructRoomFromDB(roomId);

    } catch (e) {
      debugPrint('❌ Error cargando room: $e');
      return await _reconstructRoomFromDB(roomId);
    }
  }

  // MÉTODO MEJORADO para reconstruir room desde DB
  Future<types.Room> _reconstructRoomFromDB(int roomId) async {
    try {
      debugPrint('🔧 Reconstruyendo room $roomId desde base de datos...');

      // Obtener datos de la room
      final roomData = await supabase
          .schema('chats')
          .from('rooms')
          .select('*')
          .eq('id', roomId)
          .single();

      final userIds = List<String>.from(roomData['userIds'] ?? []);
      debugPrint('🔍 UserIds en room: ${userIds.join(", ")}');

      if (userIds.length < 2) {
        throw Exception('Room no tiene suficientes usuarios');
      }

      // Obtener TODOS los usuarios de la room desde chats.users
      final usersData = <Map<String, dynamic>>[];
      for (final userId in userIds) {
        final userData = await supabase
            .schema('chats')
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();

        if (userData != null) {
          usersData.add(userData);
        }
      }

      debugPrint('🔍 Usuarios encontrados en chats.users: ${usersData.length}');

      if (usersData.length < 2) {
        throw Exception('No se encontraron todos los usuarios en chats.users');
      }

      // Crear objetos User
      final List<types.User> users = usersData.map((userData) {
        return types.User(
          id: userData['id'],
          firstName: userData['firstName'] ?? 'Usuario',
          lastName: userData['lastName'] ?? '',
          imageUrl: userData['imageUrl'],
        );
      }).toList();

      debugPrint('✅ Usuarios reconstruidos: ${users.map((u) => "${u.firstName} ${u.lastName}").join(", ")}');

      // Crear objeto Room
      final room = types.Room(
        id: roomId.toString(),
        type: types.RoomType.direct,
        users: users,
        createdAt: roomData['createdAt'],
        updatedAt: roomData['updatedAt'],
      );

      debugPrint('✅ Room reconstruida exitosamente con ${room.users.length} usuarios');
      return room;

    } catch (e) {
      debugPrint('❌ Error crítico reconstruyendo room: $e');
      throw Exception('No se pudo reconstruir la room: $e');
    }
  }

  // ✅ Debug del usuario objetivo con RPC
  Future<void> _debugTargetUser() async {
    try {
      debugPrint('🔍 === DEBUGGING USUARIO OBJETIVO ===');

      // Ver si existe en chats.users
      final chatUser = await supabase
          .schema('chats')
          .from('users')
          .select('*')
          .eq('id', widget.userId)
          .maybeSingle();

      if (chatUser != null) {
        debugPrint('✅ Usuario objetivo SÍ existe en chats.users:');
        debugPrint('   - ID: ${chatUser['id']}');
        debugPrint('   - Nombre: ${chatUser['firstName']} ${chatUser['lastName']}');
        debugPrint('   - Imagen: ${chatUser['imageUrl']}');
      } else {
        debugPrint('❌ Usuario objetivo NO existe en chats.users');

        // ✅ USAR FUNCIÓN RPC para crear usuario
        debugPrint('🔧 Creando usuario objetivo vía RPC...');
        try {
          await supabase.rpc('create_chat_user_for_others', params: {
            'target_user_id': widget.userId,
            'first_name': firstName.isNotEmpty ? firstName : (widget.userName?.split(' ').first ?? 'Usuario'),
            'last_name': lastName.isNotEmpty ? lastName : (widget.userName?.split(' ').skip(1).join(' ') ?? ''),
            'image_url': (imageUrl != 'https://placehold.co/100') ? imageUrl : widget.userImageUrl,
          });

          debugPrint('✅ Usuario objetivo creado vía RPC exitosamente');

          // Verificar que se creó
          final verifyUser = await supabase
              .schema('chats')
              .from('users')
              .select('*')
              .eq('id', widget.userId)
              .maybeSingle();

          if (verifyUser != null) {
            debugPrint('✅ Verificación: Usuario creado correctamente vía RPC');
            debugPrint('   - Nombre: ${verifyUser['firstName']} ${verifyUser['lastName']}');
          } else {
            debugPrint('❌ Verificación FALLÓ: Usuario no aparece después de RPC');
          }

          // ✅ IMPORTANTE: Esperar para que SupabaseChatCore sincronice
          debugPrint('⏳ Esperando sincronización de SupabaseChatCore...');
          await Future.delayed(const Duration(milliseconds: 1500));

        } catch (rpcError) {
          debugPrint('❌ Error con RPC: $rpcError');
          debugPrint('⚠️ Continuando sin pre-crear usuario - SupabaseChatCore intentará crearlo');
        }
      }
    } catch (e) {
      debugPrint('❌ Error en debug de usuario objetivo: $e');
    }
  }

  // ✅ Debug de usuarios en SupabaseChatCore
  Future<void> _debugSupabaseChatCoreUsers() async {
    try {
      debugPrint('🔍 === DEBUGGING SUPABASE CHAT CORE ===');

      final coreUsers = await SupabaseChatCore.instance.users();
      debugPrint('📊 Total usuarios en SupabaseChatCore: ${coreUsers.length}');

      final currentUserId = supabase.auth.currentUser!.id;
      final currentUserExists = coreUsers.any((u) => u.id == currentUserId);
      final targetUserExists = coreUsers.any((u) => u.id == widget.userId);

      debugPrint('   - Usuario actual existe: $currentUserExists');
      debugPrint('   - Usuario objetivo existe: $targetUserExists');

      if (targetUserExists) {
        final targetUser = coreUsers.firstWhere((u) => u.id == widget.userId);
        debugPrint('   - Datos usuario objetivo: "${targetUser.firstName} ${targetUser.lastName}"');
      }

      // Mostrar todos los usuarios para debugging
      for (int i = 0; i < coreUsers.length; i++) {
        final user = coreUsers[i];
        debugPrint('   [$i] ${user.firstName} ${user.lastName} (${user.id})');
      }

    } catch (e) {
      debugPrint('❌ Error obteniendo usuarios de SupabaseChatCore: $e');
    }
  }

  // ✅ Crear room con debugging completo
  Future<void> _createRoomWithDebug(String currentUserId) async {
    try {
      debugPrint('🔍 === CREANDO ROOM CON DEBUG ===');

      // Crear objeto User
      final targetUser = types.User(
        id: widget.userId,
        firstName: firstName.isNotEmpty ? firstName : (widget.userName?.split(' ').first ?? 'Usuario'),
        lastName: lastName.isNotEmpty ? lastName : (widget.userName?.split(' ').skip(1).join(' ') ?? ''),
        imageUrl: (imageUrl != 'https://placehold.co/100') ? imageUrl : widget.userImageUrl,
      );

      debugPrint('🔧 Objeto targetUser creado:');
      debugPrint('   - ID: ${targetUser.id}');
      debugPrint('   - Nombre: ${targetUser.firstName} ${targetUser.lastName}');
      debugPrint('   - Imagen: ${targetUser.imageUrl}');

      // Crear room
      debugPrint('🔧 Llamando a SupabaseChatCore.createRoom...');
      final room = await SupabaseChatCore.instance.createRoom(targetUser);

      debugPrint('✅ Room creada: ${room.id}');
      debugPrint('📊 Usuarios en room recién creada: ${room.users.length}');

      for (int i = 0; i < room.users.length; i++) {
        final user = room.users[i];
        debugPrint('   [$i] ${user.firstName} ${user.lastName} (${user.id})');
      }

      // Verificar en la base de datos
      await _verifyRoomInDB(room.id);

      // Esperar un poco y verificar de nuevo
      debugPrint('⏳ Esperando 2 segundos para sincronización...');
      await Future.delayed(const Duration(seconds: 2));

      final refreshedRooms = await SupabaseChatCore.instance.rooms();
      final refreshedRoom = refreshedRooms.where((r) => r.id == room.id).toList();

      if (refreshedRoom.isNotEmpty) {
        final finalRoom = refreshedRoom.first;
        debugPrint('🔄 Room después de refresh: ${finalRoom.users.length} usuarios');

        for (int i = 0; i < finalRoom.users.length; i++) {
          final user = finalRoom.users[i];
          debugPrint('   [$i] ${user.firstName} ${user.lastName} (${user.id})');
        }

        if (mounted) {
          debugPrint('🔄 Navegando a room...');
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RoomPage(room: finalRoom)),
          );
        }
      } else {
        debugPrint('❌ Room no encontrada después de refresh');
      }

    } catch (e) {
      debugPrint('❌ Error creando room: $e');
      throw e;
    }
  }

  // ✅ Verificar room en base de datos
  Future<void> _verifyRoomInDB(String roomId) async {
    try {
      debugPrint('🔍 === VERIFICANDO ROOM EN DB ===');

      final roomData = await supabase
          .schema('chats')
          .from('rooms')
          .select('*')
          .eq('id', int.parse(roomId))
          .single();

      debugPrint('📊 Datos de room en DB:');
      debugPrint('   - ID: ${roomData['id']}');
      debugPrint('   - Tipo: ${roomData['type']}');
      debugPrint('   - UserIds: ${roomData['userIds']}');
      debugPrint('   - Nombre: ${roomData['name']}');

    } catch (e) {
      debugPrint('❌ Error verificando room en DB: $e');
    }
  }

  // ✅ Navegar a room existente (simplificado)
  Future<void> _navigateToExistingRoom(int roomId) async {
    final rooms = await SupabaseChatCore.instance.rooms();
    final roomMatch = rooms.where((r) => r.id == roomId.toString()).toList();

    if (roomMatch.isNotEmpty && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RoomPage(room: roomMatch.first)),
      );
    }
  }

  // ✅ Crear nueva room y navegar
  Future<void> _createAndNavigateToNewRoom(String currentUserId) async {
    try {
      // Crear objeto User básico
      final targetUser = types.User(
        id: widget.userId,
        firstName: firstName.isNotEmpty ? firstName : (widget.userName?.split(' ').first ?? 'Usuario'),
        lastName: lastName.isNotEmpty ? lastName : (widget.userName?.split(' ').skip(1).join(' ') ?? ''),
        imageUrl: (imageUrl != 'https://placehold.co/100') ? imageUrl : widget.userImageUrl,
      );

      debugPrint('🔧 Creando room para: ${targetUser.firstName} ${targetUser.lastName}');

      // Crear room
      final room = await SupabaseChatCore.instance.createRoom(targetUser);
      debugPrint('✅ Room creada: ${room.id}');

      // Navegar inmediatamente (no esperar sincronización perfecta)
      if (mounted) {
        debugPrint('🔄 Navegando a nueva room...');
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RoomPage(room: room)),
        );
      }

    } catch (e) {
      debugPrint('❌ Error creando nueva room: $e');

      // FALLBACK: Si falla SupabaseChatCore, crear room directamente
      try {
        debugPrint('🔧 Intentando fallback: crear room directamente en DB...');
        await _createRoomDirectlyAndNavigate(currentUserId);
      } catch (fallbackError) {
        debugPrint('❌ Fallback también falló: $fallbackError');
        throw Exception('No se pudo crear el chat');
      }
    }
  }

  // ✅ Fallback: crear room directamente en DB
  Future<void> _createRoomDirectlyAndNavigate(String currentUserId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Insertar room en DB
    final roomData = await supabase
        .schema('chats')
        .from('rooms')
        .insert({
      'type': 'direct',
      'userIds': [currentUserId, widget.userId],
      'createdAt': now,
      'updatedAt': now,
    })
        .select('id')
        .single();

    final roomId = roomData['id'] as int;
    debugPrint('✅ Room creada directamente en DB: $roomId');

    // Crear room object básico para navegación inmediata
    final basicRoom = types.Room(
      id: roomId.toString(),
      type: types.RoomType.direct,
      users: [
        // Usuario actual (básico)
        types.User(
          id: currentUserId,
          firstName: 'Tú',
          lastName: '',
        ),
        // Usuario objetivo
        types.User(
          id: widget.userId,
          firstName: firstName.isNotEmpty ? firstName : (widget.userName?.split(' ').first ?? 'Usuario'),
          lastName: lastName.isNotEmpty ? lastName : (widget.userName?.split(' ').skip(1).join(' ') ?? ''),
          imageUrl: (imageUrl != 'https://placehold.co/100') ? imageUrl : widget.userImageUrl,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    if (mounted) {
      debugPrint('🔄 Navegando a room básica...');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RoomPage(room: basicRoom)),
      );
    }
  }

// ✅ Método seguro para crear nueva room
  Future<types.Room> _createNewRoomSafely(String currentUserId) async {
    try {
      debugPrint('🔧 Creando nueva room de forma segura...');

      // PASO 1: Crear objeto User para el objetivo
      final targetUser = types.User(
        id: widget.userId,
        firstName: firstName.isNotEmpty ? firstName : (widget.userName?.split(' ').first ?? 'Usuario'),
        lastName: lastName.isNotEmpty ? lastName : (widget.userName?.split(' ').skip(1).join(' ') ?? ''),
        imageUrl: (imageUrl != 'https://placehold.co/100') ? imageUrl : widget.userImageUrl,
      );

      debugPrint('🔧 Datos del usuario objetivo: ${targetUser.firstName} ${targetUser.lastName}');

      // PASO 2: Intentar crear la room
      try {
        final room = await SupabaseChatCore.instance.createRoom(targetUser);
        debugPrint('✅ Room creada exitosamente: ${room.id}');

        // Verificar que la room tiene usuarios
        if (room.users.length >= 2) {
          debugPrint('✅ Room válida con ${room.users.length} usuarios');
          return room;
        } else {
          debugPrint('⚠️ Room creada pero incompleta, esperando sincronización...');

          // Esperar y buscar de nuevo
          await Future.delayed(const Duration(milliseconds: 1000));

          final rooms = await SupabaseChatCore.instance.rooms();
          final refreshedRoom = rooms.where((r) => r.id == room.id).toList();

          if (refreshedRoom.isNotEmpty && refreshedRoom.first.users.length >= 2) {
            debugPrint('✅ Room sincronizada correctamente');
            return refreshedRoom.first;
          } else {
            throw Exception('Room no se sincronizó correctamente');
          }
        }

      } catch (createError) {
        debugPrint('❌ Error creando room con SupabaseChatCore: $createError');

        // FALLBACK: Crear room directamente en la base de datos
        return await _createRoomDirectlyInDB(currentUserId, targetUser);
      }

    } catch (e) {
      debugPrint('❌ Error en creación segura de room: $e');
      throw Exception('No se pudo crear la room: $e');
    }
  }

// ✅ Método fallback para crear room directamente en DB
  Future<types.Room> _createRoomDirectlyInDB(String currentUserId, types.User targetUser) async {
    try {
      debugPrint('🔧 Creando room directamente en base de datos...');

      final now = DateTime.now().millisecondsSinceEpoch;

      // Insertar room en la base de datos
      final roomData = await supabase
          .schema('chats')
          .from('rooms')
          .insert({
        'type': 'direct',
        'userIds': [currentUserId, targetUser.id],
        'createdAt': now,
        'updatedAt': now,
      })
          .select('id')
          .single();

      final roomId = roomData['id'] as int;
      debugPrint('✅ Room creada en DB con ID: $roomId');

      // Asegurar que ambos usuarios existen en chats.users
      await _ensureUserExistsInChat(currentUserId);
      await _ensureUserExistsInChat(targetUser.id, targetUser);

      // Esperar para sincronización
      await Future.delayed(const Duration(milliseconds: 500));

      // Reconstruir room desde DB
      return await _reconstructRoomFromDB(roomId);

    } catch (e) {
      debugPrint('❌ Error creando room en DB: $e');
      throw Exception('No se pudo crear room en DB: $e');
    }
  }

// ✅ Método para asegurar que un usuario existe en chats.users
  Future<void> _ensureUserExistsInChat(String userId, [types.User? userObj]) async {
    try {
      // Verificar si ya existe
      final existing = await supabase
          .schema('chats')
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('✅ Usuario $userId ya existe en chats');
        return;
      }

      debugPrint('🔧 Creando usuario $userId en chats...');

      // Obtener datos del usuario
      String userFirstName = 'Usuario';
      String userLastName = '';
      String? userImageUrl;

      if (userObj != null) {
        userFirstName = userObj.firstName ?? 'Usuario';
        userLastName = userObj.lastName ?? '';
        userImageUrl = userObj.imageUrl;
      } else {
        // Buscar en users
        final profileData = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl')
            .eq('id', userId)
            .maybeSingle();

        if (profileData != null) {
          userFirstName = profileData['firstName'] ?? 'Usuario';
          userLastName = profileData['lastName'] ?? '';
          userImageUrl = profileData['imageUrl'];
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      // Solo insertar si es el usuario actual (para evitar RLS)
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null && userId == currentUser.id) {
        await supabase
            .schema('chats')
            .from('users')
            .insert({
          'id': userId,
          'firstName': userFirstName,
          'lastName': userLastName,
          'imageUrl': userImageUrl,
          'createdAt': now,
          'updatedAt': now,
        });

        debugPrint('✅ Usuario $userId creado en chats');
      } else {
        debugPrint('⚠️ No se puede crear usuario $userId debido a RLS (no es el usuario actual)');
      }

    } catch (e) {
      debugPrint('❌ Error asegurando usuario en chat: $e');
    }
  }

// ✅ Método de búsqueda de room simplificado
  Future<int?> _findExistingRoomInDB(String currentUserId, String targetUserId) async {
    try {
      debugPrint('🔍 Buscando room existente...');

      final result = await supabase
          .schema('chats')
          .from('rooms')
          .select('id')
          .contains('userIds', [currentUserId, targetUserId])
          .eq('type', 'direct')
          .maybeSingle();

      if (result != null) {
        final roomId = result['id'] as int;
        debugPrint('✅ Room existente encontrada: $roomId');
        return roomId;
      } else {
        debugPrint('❌ No existe room previa');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error buscando room: $e');
      return null;
    }
  }

  // Método auxiliar para asegurar que el usuario actual existe
  Future<void> _ensureCurrentUserExists(String currentUserId) async {
    try {
      debugPrint('🔍 Verificando usuario actual en chat: $currentUserId');

      // Verificar si existe en el esquema chats
      final existingUser = await supabase
          .schema('chats')
          .from('users')
          .select('id, firstName, lastName, imageUrl')
          .eq('id', currentUserId)
          .maybeSingle();

      if (existingUser == null) {
        debugPrint('🔧 Usuario actual no existe, creándolo...');

        // Obtener datos del usuario actual desde auth o profile
        final userProfile = await supabase
            .schema('chats')
            .from('users')
            .select('firstName, lastName, imageUrl')
            .eq('id', currentUserId)
            .maybeSingle();

        // Usar timestamp en milisegundos (bigint)
        final now = DateTime.now().millisecondsSinceEpoch;

        // Upsert con timestamp como bigint
        await supabase
            .schema('chats')
            .from('users').upsert({
          'id': currentUserId,
          'firstName': userProfile?['firstName'] ?? 'Usuario',
          'lastName': userProfile?['lastName'] ?? '',
          'imageUrl': userProfile?['imageUrl'],
          'createdAt': now,
          'updatedAt': now,
        });

        debugPrint('✅ Usuario actual creado en chat');
      } else {
        debugPrint('✅ Usuario actual ya existe en chat: ${existingUser['firstName']} ${existingUser['lastName']}');
      }
    } catch (e) {
      debugPrint('❌ Error verificando usuario actual: $e');
    }
  }

  Widget _buildSkillChip(String skill, {required String nivel}) => Chip(
    label: Text(skill, style: const TextStyle(color: Color(0xFF2563EB))),
    backgroundColor: const Color(0xFFEFF6FF),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  Widget _buildLocationSection() => Column(
    children: [
      const SizedBox(height: 15),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Ubicación',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: Colors.blue.shade700,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubicación de trabajo',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  isLoadingLocation
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    currentLocationAddress,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(isLoading ? (widget.userName ?? 'Perfil') : '$firstName $lastName'),
        centerTitle: false,
        backgroundColor: Colors.blue,
        elevation: 2,
        shadowColor: Colors.blue.withOpacity(0.3),
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Foto de perfil
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(imageUrl),
              onBackgroundImageError: (_, __) => const Icon(Icons.error),
            ),
            const SizedBox(height: 10),

            // Información básica
            Text(
              '$firstName $lastName',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            // Calificaciones
            isLoadingReviews
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 5),
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 5),
                Text(
                  '($totalReviews ${totalReviews == 1 ? 'review' : 'reviews'})',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 15),
            // Botón de mensaje directo (simplificado)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleChatPressed,
                icon: const Icon(Icons.message, color: Colors.white),
                label: const Text(
                  'Mensaje Directo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Descripción
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Sobre mí', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                descripcion,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),

            // Habilidades
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Habilidades', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...userSkills.map((skill) => _buildSkillChip(
                  skill['name'],
                  nivel: skill['nivel'],
                ),),
                if (userSkills.isEmpty)
                  const Text('No hay habilidades añadidas', style: TextStyle(color: Colors.grey)),
              ],
            ),

            // Sección de ubicación
            _buildLocationSection(),
            const SizedBox(height: 15),

            // Categorías y oficios
            if (userCategories.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Especialidades', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              ...userCategories.map((category) {
                final categoryId = category['id'] as int;
                final oficios = userOficios[categoryId] ?? [];

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category['name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (oficios.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: oficios.map((oficio) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade300),
                            ),
                            child: Text(
                              oficio['name'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 15),
            ],

            UserOffersWidget(userId: widget.userId),
          ],
        ),
      ),
    );
}