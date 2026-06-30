// src/managers/location_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationManager extends ChangeNotifier {
  // Estado de la ubicación
  LatLng? _currentPosition;
  String? _currentSector;
  bool _isLoading = true;
  String _errorMessage = '';

  StreamSubscription<Position>? _positionStreamSubscription;

  // Getters
  LatLng? get currentPosition => _currentPosition;
  String? get currentSector => _currentSector;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Constructor
  LocationManager();

  // Determinar si debemos actualizar los trabajadores cercanos
  // ignore: unused_element
  bool _shouldRefreshWorkers(LatLng newPosition) {
    if (_currentPosition == null) return true;

    const distance = Distance();
    final distanceMoved = distance.as(
        LengthUnit.Meter,
        _currentPosition!,
        newPosition,
    );

    // Si nos movimos más de 50 metros, actualizar los trabajadores cercanos
    return distanceMoved > 50;
  }

  // Actualizar la posición actual
  // Método updatePosition con notificación
  Future<void> updatePosition(LatLng newPosition, Function(LatLng) determineSector) async {
    try {
      if (kDebugMode) {
        print('📍 LocationManager: Actualizando posición a $newPosition');
      }

      _currentPosition = newPosition;
      _errorMessage = '';

      // Determinar sector
      determineSector(newPosition);

      // ✅ NUEVO: Guardar en base de datos si el usuario está autenticado
      await _saveLocationToDatabase(newPosition);

      // Notificar a los listeners (incluyendo MapScreen)
      notifyListeners();

      if (kDebugMode) {
        print('✅ LocationManager: Posición actualizada exitosamente');
      }

    } catch (e) {
      _errorMessage = 'Error actualizando ubicación: $e';
      if (kDebugMode) {
        print('❌ LocationManager: Error actualizando posición: $e');
      }
      notifyListeners();
    }
  }

  // Guardar ubicación en base de datos
  Future<void> _saveLocationToDatabase(LatLng position) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        print('💾 Guardando ubicación en base de datos...');
      }

      await Supabase.instance.client
          .schema('jobs')
          .from('worker_locations')
          .upsert({
        'user_id': user.id,
        'latitud': position.latitude,
        'longitud': position.longitude,
        'user_type': 'worker',
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('✅ Ubicación guardada en base de datos');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error guardando ubicación en BD: $e');
      }
      // No lanzar el error para no interrumpir el flujo
    }
  }

  // Cargar ubicación desde base de datos
  Future<LatLng?> loadLocationFromDatabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final locationData = await Supabase.instance.client
          .schema('jobs')
          .from('worker_locations')
          .select('latitud, longitud')
          .eq('user_id', user.id)
          .eq('user_type', 'worker')
          .maybeSingle();

      if (locationData != null) {
        final lat = locationData['latitud'] is String
            ? double.parse(locationData['latitud'])
            : locationData['latitud'].toDouble();
        final lng = locationData['longitud'] is String
            ? double.parse(locationData['longitud'])
            : locationData['longitud'].toDouble();

        return LatLng(lat, lng);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cargando ubicación desde BD: $e');
      }
      return null;
    }
  }

  // Configuración de la ubicación
  // initializeLocation con mejor lógica
  Future<bool> initializeLocation(Function(LatLng) determineSector, {required bool forceUpdate}) async {
    setLoading(true);

    try {
      // 1. Intentar cargar ubicación guardada primero
      final savedLocation = await loadLocationFromDatabase();
      if (savedLocation != null) {
        if (kDebugMode) {
          print('📍 Usando ubicación guardada: $savedLocation');
        }
        await updatePosition(savedLocation, determineSector);
        setLoading(false);
        return true;
      }

      // 2. Si no hay ubicación guardada, usar GPS
      if (kDebugMode) {
        print('📍 No hay ubicación guardada, obteniendo ubicación GPS...');
      }

      // Verificar permisos
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setErrorMessage('Los servicios de ubicación están deshabilitados');
        setLoading(false);
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setErrorMessage('Permisos de ubicación denegados');
          setLoading(false);
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setErrorMessage('Permisos de ubicación denegados permanentemente');
        setLoading(false);
        return false;
      }

      _startLocationUpdates(determineSector);

      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentPos = LatLng(position.latitude, position.longitude);
      await updatePosition(currentPos, determineSector);

      setLoading(false);
      return true;

    } catch (e) {
      setErrorMessage('Error obteniendo ubicación: $e');
      setLoading(false);
      return false;
    }
  }

  // Iniciar escucha continua de ubicación con Foreground Service
  void _startLocationUpdates(Function(LatLng) determineSector) {
    if (kDebugMode) {
      print('📍 Iniciando Foreground Service de ubicación...');
    }

    // Configuración específica para forzar la notificación en Android
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualiza cada vez que te muevas 10 metros
      forceLocationManager: true,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'PerDiem está actualizando tu ubicación en tiempo real.',
        notificationTitle: 'Ubicación activa',
        enableWakeLock: true,
      ),
    );

    // Cancelar cualquier escucha anterior por seguridad
    _positionStreamSubscription?.cancel();

    // Iniciar el stream constante
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final currentPos = LatLng(position.latitude, position.longitude);
      // Reutilizamos tu método updatePosition cada vez que nos movemos
      updatePosition(currentPos, determineSector);
    });
  }

  // Métodos para manipular el estado
  void setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  void setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}