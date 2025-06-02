// Archivo: lib/services/geographic_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeographicLocation {
  final String name;
  final String code;
  final LatLng? coordinates;
  final List<GeographicLocation>? subdivisions;

  GeographicLocation({
    required this.name,
    required this.code,
    this.coordinates,
    this.subdivisions,
  });

  factory GeographicLocation.fromJson(Map<String, dynamic> json) => GeographicLocation(
      name: json['name'] ?? '',
      code: json['iso2'] ?? json['code'] ?? '',
      coordinates: json['latitude'] != null && json['longitude'] != null
          ? LatLng(json['latitude'].toDouble(), json['longitude'].toDouble())
          : null,
    );
}

class GeographicService {
  static const String _baseUrl = 'https://countriesnow.space/api/v0.1';
  static const String _restCountriesUrl = 'https://restcountries.com/v3.1';

  // Cache para evitar llamadas repetidas
  static final Map<String, List<GeographicLocation>> _countryCache = {};
  static final Map<String, List<GeographicLocation>> _stateCache = {};
  static List<GeographicLocation>? _countriesCache;

  // Obtener todos los países
  static Future<List<GeographicLocation>> getCountries() async {
    if (_countriesCache != null) {
      return _countriesCache!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/countries'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countries = (data['data'] as List)
            .map((country) => GeographicLocation(
          name: country['country'] ?? '',
          code: country['iso2'] ?? '',
          ),
        )
            .toList();

        // Ordenar alfabéticamente
        countries.sort((a, b) => a.name.compareTo(b.name));
        _countriesCache = countries;
        return countries;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo países: $e');
      }
    }

    // Fallback con países principales si falla la API
    return _getFallbackCountries();
  }

  // Obtener estados/regiones de un país
  static Future<List<GeographicLocation>> getStates(String countryName) async {
    if (_stateCache.containsKey(countryName)) {
      return _stateCache[countryName]!;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/countries/states'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'country': countryName}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final states = (data['data']['states'] as List)
            .map((state) => GeographicLocation(
          name: state['name'] ?? '',
          code: state['state_code'] ?? '',
          ),
        )
            .toList();

        // Ordenar alfabéticamente
        states.sort((a, b) => a.name.compareTo(b.name));
        _stateCache[countryName] = states;
        return states;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo estados para $countryName: $e');
      }
    }

    return [];
  }

  // Obtener ciudades de un estado
  static Future<List<GeographicLocation>> getCities(String countryName, String stateName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/countries/state/cities'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'country': countryName,
          'state': stateName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final cities = (data['data'] as List)
            .map((city) => GeographicLocation(
          name: city.toString(),
          code: city.toString().toLowerCase().replaceAll(' ', '_'),
          ),
        )
            .toList();

        // Ordenar alfabéticamente
        cities.sort((a, b) => a.name.compareTo(b.name));
        return cities;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo ciudades para $stateName, $countryName: $e');
      }
    }

    return [];
  }

  // Geocodificación: obtener coordenadas de una dirección
  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      // Usando Nominatim (OpenStreetMap) - gratuito
      final encodedAddress = Uri.encodeComponent(address);
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1'),
        headers: {'User-Agent': 'FlutterApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en geocodificación: $e');
      }
    }

    return null;
  }

  // Geocodificación inversa: obtener dirección de coordenadas
  static Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${coordinates.latitude}&lon=${coordinates.longitude}&format=json',
        ),
        headers: {'User-Agent': 'FlutterApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en geocodificación inversa: $e');
      }
    }

    return null;
  }

  // Detectar país basado en coordenadas
  static Future<String?> getCountryFromCoordinates(LatLng coordinates) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${coordinates.latitude}&lon=${coordinates.longitude}&format=json&addressdetails=1',
        ),
        headers: {'User-Agent': 'FlutterApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['address']?['country'];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error detectando país: $e');
      }
    }

    return null;
  }

  // Buscar ubicaciones por texto
  static Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=10&addressdetails=1'),
        headers: {'User-Agent': 'FlutterApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((item) => {
          'name': item['display_name'],
          'coordinates': LatLng(
            double.parse(item['lat']),
            double.parse(item['lon']),
          ),
          'country': item['address']?['country'],
          'state': item['address']?['state'],
          'city': item['address']?['city'] ?? item['address']?['town'] ?? item['address']?['municipality'],
          },
        ).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error buscando ubicaciones: $e');
      }
    }

    return [];
  }

  // Datos de fallback en caso de que fallen las APIs
  static List<GeographicLocation> _getFallbackCountries() => [
      GeographicLocation(name: 'Chile', code: 'CL'),
      GeographicLocation(name: 'Argentina', code: 'AR'),
      GeographicLocation(name: 'Brazil', code: 'BR'),
      GeographicLocation(name: 'Colombia', code: 'CO'),
      GeographicLocation(name: 'Mexico', code: 'MX'),
      GeographicLocation(name: 'Peru', code: 'PE'),
      GeographicLocation(name: 'United States', code: 'US'),
      GeographicLocation(name: 'Spain', code: 'ES'),
      GeographicLocation(name: 'France', code: 'FR'),
      GeographicLocation(name: 'Germany', code: 'DE'),
    ];

  // Datos específicos para Chile (fallback)
  static Map<String, List<String>> getChileData() => {
      'Región de Tarapacá': ['Iquique', 'Alto Hospicio', 'Pozo Almonte', 'Pica', 'Huara', 'Camiña', 'Colchane'],
      'Región de Antofagasta': ['Antofagasta', 'Calama', 'Tocopilla', 'Mejillones', 'Taltal', 'Sierra Gorda', 'San Pedro de Atacama'],
      'Región de Atacama': ['Copiapó', 'Vallenar', 'Chañaral', 'Diego de Almagro', 'Caldera', 'Tierra Amarilla', 'Huasco'],
      'Región de Coquimbo': ['La Serena', 'Coquimbo', 'Ovalle', 'Illapel', 'Vicuña', 'Combarbalá', 'Monte Patria'],
      'Región de Valparaíso': ['Valparaíso', 'Viña del Mar', 'San Antonio', 'Quilpué', 'Villa Alemana', 'Limache', 'Quillota'],
      'Región Metropolitana': ['Santiago', 'Las Condes', 'Providencia', 'Maipú', 'Ñuñoa', 'La Florida', 'Puente Alto'],
      'Región del Libertador General Bernardo O\'Higgins': ['Rancagua', 'San Fernando', 'Rengo', 'Machalí', 'Graneros', 'Mostazal'],
      'Región del Maule': ['Talca', 'Curicó', 'Linares', 'Cauquenes', 'Constitución', 'Molina', 'Parral'],
      'Región del Biobío': ['Concepción', 'Talcahuano', 'Chillán', 'Los Ángeles', 'Coronel', 'San Pedro de la Paz'],
      'Región de La Araucanía': ['Temuco', 'Angol', 'Villarrica', 'Pucón', 'Nueva Imperial', 'Lautaro', 'Pitrufquén'],
      'Región de Los Ríos': ['Valdivia', 'La Unión', 'Río Bueno', 'Panguipulli', 'Lanco', 'Mariquina'],
      'Región de Los Lagos': ['Puerto Montt', 'Osorno', 'Castro', 'Ancud', 'Puerto Varas', 'Frutillar', 'Llanquihue'],
      'Región Aysén del General Carlos Ibáñez del Campo': ['Coyhaique', 'Puerto Aysén', 'Chile Chico', 'Cochrane'],
      'Región de Magallanes y de la Antártica Chilena': ['Punta Arenas', 'Puerto Natales', 'Porvenir', 'Cabo de Hornos'],
    };

  // Limpiar caché
  static void clearCache() {
    _countryCache.clear();
    _stateCache.clear();
    _countriesCache = null;
  }
}