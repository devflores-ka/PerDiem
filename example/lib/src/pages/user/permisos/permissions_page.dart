import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermisosUbicacionScreen extends StatefulWidget {
  const PermisosUbicacionScreen({super.key});

  @override
  State<PermisosUbicacionScreen> createState() => _PermisosUbicacionScreenState();
}

class _PermisosUbicacionScreenState extends State<PermisosUbicacionScreen> {
  bool _servicioHabilitado = false;
  LocationPermission _permisoActual = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    _verificarEstadoInicial();
  }

  Future<void> _verificarEstadoInicial() async {
    // Verificar si el servicio de ubicación está habilitado
    _servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    
    // Verificar el estado actual de los permisos
    _permisoActual = await Geolocator.checkPermission();

    setState(() {});
  }

  Future<void> _solicitarPermiso() async {
    // Si los servicios de ubicación no están habilitados, mostrar un diálogo
    if (!_servicioHabilitado) {
      final resultado = await _mostrarDialogoServiciosUbicacion();
      if (resultado == false) return;
    }

    // Solicitar permiso de ubicación
    _permisoActual = await Geolocator.requestPermission();

    switch (_permisoActual) {
      case LocationPermission.denied:
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El permiso de ubicación es requerido para continuar.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      
      case LocationPermission.deniedForever:
        // Mostrar diálogo para abrir configuraciones
        await _mostrarDialogoConfiguracion();
        break;
      
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        // ignore: use_build_context_synchronously
        Navigator.pop(context, true);
        break;
      
      case LocationPermission.unableToDetermine:
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede determinar el estado de los permisos.'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }

  Future<bool?> _mostrarDialogoServiciosUbicacion() async => showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Servicios de Ubicación Desactivados'),
        content: const Text('Por favor, activa los servicios de ubicación para continuar.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.of(context).pop(true);
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );

  Future<void> _mostrarDialogoConfiguracion() async => showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permiso de Ubicación Bloqueado'),
        content: const Text('Los permisos de ubicación están bloqueados permanentemente. Por favor, habilítelos desde la configuración de la aplicación.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ph.openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Permiso de Ubicación')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Para publicar ofertas, necesitamos acceder a tu ubicación. Esto nos permite sugerir servicios cercanos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            // Mostrar estado actual de los servicios y permisos
            if (!_servicioHabilitado)
              const Text(
                'Los servicios de ubicación están desactivados',
                style: TextStyle(color: Colors.red),
              ),
            if (_permisoActual == LocationPermission.deniedForever)
              const Text(
                'Los permisos de ubicación están bloqueados permanentemente',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _solicitarPermiso,
              child: const Text('Conceder Permiso'),
            ),
          ],
        ),
      ),
    );
}