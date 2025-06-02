import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final supabase = Supabase.instance.client;
  bool _initialized = false;
  bool _isUpdatingToken = false; // Para evitar actualizaciones de tokens simultáneas

  // Inicializar el servicio
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kDebugMode) {
        print('🚀 Inicializando NotificationService');
      }

      // Configurar handlers de mensajes primero para no perder notificaciones
      _setupMessageHandlers();

      // Solicitar permisos
      await requestNotificationPermissions();

      // Escuchar cambios de autenticación
      supabase.auth.onAuthStateChange.listen((event) async {
        if (event.event == AuthChangeEvent.signedIn) {
          if (kDebugMode) {
            print('🔑 Login exitoso, verificando token FCM...');
          }

          // Ejecutar en un Future.microtask para no bloquear la UI después del login
          await Future.microtask(() => _handlePostLoginTokenSync());
        } else if (event.event == AuthChangeEvent.signedOut) {
          if (kDebugMode) {
            print('🚪 Logout detectado - no se requiere acción para FCM');
          }
        }
      });

      // Escuchar refrescos de token
      FirebaseMessaging.instance.onTokenRefresh.listen(_handleTokenRefresh);

      _initialized = true;

      // Verificar token actual si hay un usuario logueado
      if (supabase.auth.currentUser != null) {
        await Future.microtask(() => syncFcmToken());
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'ℹ️ Error en inicialización de notificaciones, pero la app continuará: $e',);
      }
      // Marcar como inicializado para evitar reintentos
      _initialized = true;
    }
  }

  // Métodos públicos para pedir permisos
  Future<NotificationSettings> requestNotificationPermissions() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        print('🔔 Estado de permisos de notificación: ${settings
            .authorizationStatus}');
      }

      return settings;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al pedir permisos de notificación: $e');
      }
      rethrow;
    }
  }

  // Manejar el procesamiento post-login de forma atómica
  Future<void> _handlePostLoginTokenSync() async {
    try {
      await syncFcmToken();
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Error al sincronizar token después de login: $e');
      }
    }
  }

  // Manejar eventos de actualización de tokens desde Firebase
  Future<void> _handleTokenRefresh(String token) async {
    if (kDebugMode) {
      print('🔄 Token FCM refrescado: $token');
    }

    if (token.isNotEmpty && supabase.auth.currentUser != null) {
      await _saveFcmToken(token);
    }
  }

  // Configurar controladores de mensajes de notificación
  void _setupMessageHandlers() {
    // Para recibir mensajes cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(notification.title, notification.body);
      }
    });

    // Para manejar el clic en una notificación cuando la app está en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle navigation based on message data
      _handleNotificationNavigation(message);
    });
  }

  // Mostrar notificación local
  void _showLocalNotification(String? title, String? body) {
    if (title != null || body != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${title ?? ''} ${body ?? ''}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Cerrar',
            onPressed: () {
              scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  // Gestionar la navegación en función de los datos de notificación
  void _handleNotificationNavigation(RemoteMessage message) {
    // Implementar lógica de navigación basada en message.data
    final data = message.data;
    if (data.containsKey('room_id')) {
      // Navegar a la sala de chat
      if (kDebugMode) {
        print('🧭 Navegando a sala: ${data['room_id']}');
      }

      // Ejemplo de código de navigación:
      // Navigator.of(navigatorKey.currentContext!).pushNamed(
      //   '/chat_room',
      //   arguments: {'roomId': data['room_id']},
      // );
    }
  }

  // Sincronizar el token FCM con la base de datos
  Future<void> syncFcmToken() async {
    // Solo un proceso de actualización a la vez
    if (_isUpdatingToken) return;
    _isUpdatingToken = true;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          print('ℹ️ No hay usuario autenticado para sincronizar el token FCM');
        }
        return;
      }

      // Obtener el token actual del dispositivo
      final currentDeviceToken = await FirebaseMessaging.instance.getToken();
      if (currentDeviceToken == null || currentDeviceToken.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ No se pudo obtener un token FCM válido del dispositivo');
        }
        return;
      }

      // Verificar si necesitamos actualizar el token
      if (await _shouldUpdateToken(userId, currentDeviceToken)) {
        await _saveFcmToken(currentDeviceToken);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Error en sincronización de token FCM: $e');
      }
    } finally {
      _isUpdatingToken = false;
    }
  }

  // Verificar si el token necesita actualizarse
  Future<bool> _shouldUpdateToken(String userId,
      String currentDeviceToken,) async {
    try {
      // Primero verificamos si podemos leer la tabla profiles
      try {
        final response = await supabase
            .schema('chats')
            .from('profiles')
            .select('fmc_token')
            .eq('id', userId)
            .maybeSingle();

        // Si no hay registro o el token es diferente, actualizar
        final storedToken = response?['fmc_token'] as String?;

        if (storedToken == null || storedToken != currentDeviceToken) {
          if (kDebugMode) {
            print('🔄 Token FCM requiere actualización:');
            print('📱 Token del dispositivo: $currentDeviceToken');
            print('💾 Token en base de datos: $storedToken');
          }
          return true;
        }

        if (kDebugMode) {
          print('✅ Token FCM ya está sincronizado para el usuario $userId');
        }
        return false;
      } catch (e) {
        // Si hay un error de permisos en la operación SELECT, asumimos que el perfil aún no existe
        if (e is PostgrestException && e.code == '42501') {
          if (kDebugMode) {
            print(
              '⚠️ No se pudo leer el token actual debido a restricciones RLS. Intentando otros métodos.',);
          }
          return true;
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al verificar token FCM en base de datos: $e');
      }
      // Si hay error, asumimos que necesitamos actualizar
      return true;
    }
  }

  // Guardar token FCM en la base de datos utilizando una lista de estrategias priorizadas
  Future<void> _saveFcmToken(String token) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Lista de estrategias de guardado, ordenadas por preferencia
    final strategies = <Future<bool> Function()>[
      // Estrategia 1: RPC - Es preferible ya que puede tener privilegios especiales
          () async {
        try {
          await supabase.rpc('update_fcm_token',
            params: {
              'p_user_id': userId,
              'p_token': token,
            },
          );
          if (kDebugMode) {
            print('✅ Token FCM guardado correctamente mediante RPC');
          }
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('ℹ️ Estrategia RPC falló: $e');
          }
          return false;
        }
      },

      // Estrategia 2: Update - Menos invasiva, solo actualiza si ya existe
          () async {
        try {
          await supabase
              .schema('chats')
              .from('profiles')
              .update({'fmc_token': token})
              .eq('id', userId);
          if (kDebugMode) {
            print('✅ Token FCM guardado correctamente mediante UPDATE');
          }
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('ℹ️ Estrategia update falló: $e');
          }
          return false;
        }
      },

      // Estrategia 3: Upsert - Más versátil pero puede fallar por RLS
          () async {
        try {
          await supabase
              .schema('chats')
              .from('profiles')
              .upsert(
            {
              'id': userId,
              'fmc_token': token,
            },
            onConflict: 'id',
          );
          if (kDebugMode) {
            print('✅ Token FCM guardado correctamente mediante UPSERT');
          }
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('ℹ️ Estrategia upsert falló: $e');
          }
          return false;
        }
      },

      // Estrategia 4: Insert - Última opción, intenta crear el registro
          () async {
        try {
          await supabase
              .schema('chats')
              .from('profiles')
              .insert({
            'id': userId,
            'fmc_token': token,
          });
          if (kDebugMode) {
            print('✅ Token FCM guardado correctamente mediante INSERT');
          }
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('ℹ️ Estrategia insert falló: $e');
          }
          return false;
        }
      },
    ];

    // Ejecutar estrategias hasta que una funcione
    for (var strategy in strategies) {
      if (await strategy()) {
        if (kDebugMode) {
          print('✅ Token FCM guardado correctamente: $token');
        }
        return;
      }
    }

    if (kDebugMode) {
      print('⚠️ No se pudo guardar el token FCM después de todos los intentos');
    }
  }

  // Métodos auxiliares públicos para depuración
  Future<void> debugCheckTokenRegistration() async {
    if (!kDebugMode) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (kDebugMode) {
        print('🔍 DEBUG - No hay usuario autenticado');
      }
      return;
    }

    final deviceToken = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      print('🔍 DEBUG - Token FCM del dispositivo: $deviceToken');
    }

    try {
      final storedData = await supabase
          .schema('chats')
          .from('profiles')
          .select('fmc_token')
          .eq('id', userId)
          .maybeSingle();

      final storedToken = storedData?['fmc_token'] as String?;
      if (kDebugMode) {
        print('🔍 DEBUG - Token almacenado en BD: $storedToken');
      }

      if (storedToken == null || storedToken.isEmpty) {
        if (kDebugMode) {
          print(
            '❌ VERIFICACIÓN FALLIDA: Token FCM no registrado para usuario $userId',);
        }
      } else if (deviceToken != storedToken) {
        if (kDebugMode) {
          print(
            '⚠️ INCONSISTENCIA: El token del dispositivo no coincide con la base de datos',);
        }
        if (kDebugMode) {
          print('  Dispositivo: $deviceToken');
        }
        if (kDebugMode) {
          print('  Base datos: $storedToken');
        }
      } else {
        if (kDebugMode) {
          print('✅ VERIFICACIÓN EXITOSA: Token FCM registrado correctamente');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error de verificación: $e');
      }
    }
  }

  // Método público para asegurar que el token esta registrado
  Future<void> ensureTokenIsRegistered() async {
    if (kDebugMode) {
      print('🔒 Asegurando que el token FCM esté registrado');
    }
    // Ejecutar en un Future.microtask para evitar bloquear la UI
    await Future.microtask(syncFcmToken);
  }

  // Métodos estáticos para enviar notificaciones de ofertas
  static Future<void> sendNewChatNotification(String receiverId,
      String chatName,) async {
    if (receiverId.isEmpty || chatName.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Error: receiverId o chatName están vacíos');
      }
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      if (kDebugMode) {
        print(
          '📨 Enviando notificación al usuario con ID: $receiverId para el chat: $chatName',);
      }

      // Obtener el token FCM del receptor
      final response = await supabase
          .schema('chats')
          .from('profiles')
          .select('fmc_token')
          .eq('id', receiverId)
          .maybeSingle();

      final token = response?['fmc_token'] as String?;
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Usuario $receiverId no tiene un token FCM registrado');
        }
        return;
      }

      if (kDebugMode) {
        print('🔑 Token FCM encontrado para el usuario $receiverId: $token');
      }

      // Send notification through Supabase Edge Function
      final result = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'token': token,
          'title': 'Nuevo Chat',
          'body': '¡Te han contactado para "$chatName"!',
          'data': {
            'type': 'new_chat',
            'room_id': chatName,
          },
        },
      );

      if (kDebugMode) {
        print('✅ Notificación enviada correctamente al usuario: $receiverId');
        print('📊 Respuesta de la función: ${result.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enviando la notificación: $e');
        print('Rastreo de error en la pila: ${StackTrace.current}');
      }
      // Vuelva a lanzar el error para que quien lo llama pueda manejarlo
      throw Exception('Fallo al enviar notificación: $e');
    }
  }

  static Future<void> sendNewMessageNotification(
      String receiverId,
      String senderName,
      String message,
      String roomId, {
        String? senderId,
      }) async {
    if (receiverId.isEmpty || senderName.isEmpty || roomId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Error: receiverId, senderName, o roomId están vacíos');
        print('  receiverId: $receiverId');
        print('  senderName: $senderName');
        print('  roomId: $roomId');
      }
      return;
    }

    final supabase = Supabase.instance.client;
    final userId = senderId ?? supabase.auth.currentUser?.id ?? 'unknown';

    try {
      if (kDebugMode) {
        print('📨 Invocando función Edge `notify_new_message`');
      }

      // Recortar el mensaje si es muy largo
      final messageBody =
      message.length > 100 ? '${message.substring(0, 97)}...' : message;

      if (kDebugMode) {
        print('📦 Payload enviado a Edge Function:');
        print({
          'receiver_id': receiverId,
          'title': senderName,
          'body': messageBody,
          'data': {
            'type': 'new_message',
            'room_id': roomId,
            'sender_id': userId,
          },
        });
      }

      // Enviar notificación a través de la función Edge
      final result = await supabase.functions.invoke(
        'notify_new_message',
        body: {
          'receiver_id': receiverId,
          'title': senderName,
          'body': messageBody,
          'data': {
            'type': 'new_message',
            'room_id': roomId,
            'sender_id': userId,
          },
        },
      );

      if (kDebugMode) {
        print('✅ Notificación de mensaje enviada mediante Edge Function');
        print('📊 Respuesta: ${result.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al enviar notificación mediante función Edge: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      // No relanzamos para evitar errores colaterales
    }
  }

}