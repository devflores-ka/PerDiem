import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/notification_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _locationServiceEnabled = false;
  LocationPermission _locationPermissionStatus = LocationPermission.denied;
  AuthorizationStatus _notificationPermissionStatus = AuthorizationStatus.notDetermined;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    // Check location service and permission
    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    _locationPermissionStatus = await Geolocator.checkPermission();

    // Check notification permission
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    _notificationPermissionStatus = settings.authorizationStatus;

    setState(() {});
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    // Your existing location permission code
    // ...
  }

  // Request notification permission
  Future<void> _requestNotificationPermission() async {
    // Usar el método existente en NotificationService
    final settings = await NotificationService().requestNotificationPermissions();

    setState(() {
      _notificationPermissionStatus = settings.authorizationStatus;
    });

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Usar syncFcmToken en lugar de refreshAndSaveToken
      await NotificationService().syncFcmToken();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Permiso de notificaciones concedido!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las notificaciones son importantes para mantener comunicación.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Permisos de la App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Location permission section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.location_on, size: 50, color: Colors.blue),
                    const Text(
                      'Ubicación',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Necesitamos acceder a tu ubicación para sugerir servicios cercanos.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    _buildPermissionStatus(
                        'Ubicación',
                        _locationPermissionStatus == LocationPermission.whileInUse ||
                            _locationPermissionStatus == LocationPermission.always,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _requestLocationPermission,
                      child: const Text('Conceder Permiso de Ubicación'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Notification permission section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.notifications, size: 50, color: Colors.amber),
                    const Text(
                      'Notificaciones',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Necesitamos enviar notificaciones para mantenerte informado sobre nuevos mensajes y chats.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    _buildPermissionStatus(
                        'Notificaciones',
                        _notificationPermissionStatus == AuthorizationStatus.authorized ||
                            _notificationPermissionStatus == AuthorizationStatus.provisional,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _requestNotificationPermission,
                      child: const Text('Conceder Permiso de Notificaciones'),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: _areAllPermissionsGranted()
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );

  Widget _buildPermissionStatus(String permissionType, bool granted) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(
          granted
              ? 'Permiso concedido'
              : 'Permiso pendiente',
          style: TextStyle(
            color: granted ? Colors.green : Colors.red,
          ),
        ),
      ],
    );

  bool _areAllPermissionsGranted() {
    final locationGranted =
        _locationPermissionStatus == LocationPermission.whileInUse ||
            _locationPermissionStatus == LocationPermission.always;

    final notificationsGranted =
        _notificationPermissionStatus == AuthorizationStatus.authorized ||
            _notificationPermissionStatus == AuthorizationStatus.provisional;

    return locationGranted && notificationsGranted;
  }
}