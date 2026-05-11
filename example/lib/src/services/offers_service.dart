import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para gestionar ofertas de trabajo
class OffersService {
  // Singleton pattern
  static final OffersService _instance = OffersService._internal();
  factory OffersService() => _instance;
  OffersService._internal();

  final double _radiusKm = 10.0; // Radio de búsqueda por defecto

  /// Obtiene ofertas cercanas (RPC) o por búsqueda (Query estándar)
  /// MODIFICADO: Ahora soporta búsqueda híbrida
  Future<List<Map<String, dynamic>>> getNearbyOffers({
    required LatLng position,
    String? category,
    double? radius,
    String? query,        // <--- NUEVO
    String? oficioName,   // <--- NUEVO
  }) async {
    try {
      final bool isSearchMode = (query != null && query.isNotEmpty) || 
                                (oficioName != null && oficioName.isNotEmpty);

      if (isSearchMode) {
        // --- MODO BÚSQUEDA (Nueva lógica) ---
        return await _searchOffersStandard(
          query: query,
          category: category,
          oficioName: oficioName,
        );
      } else {
        // --- MODO GPS (Tu lógica original intacta) ---
        return await _getOffersByRPC(
          position: position,
          category: category,
          radius: radius,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en getNearbyOffers: $e');
      }
      return [];
    }
  }

  // --- LÓGICA PRIVADA (Separa lo nuevo de lo viejo) ---

  Future<List<Map<String, dynamic>>> _getOffersByRPC({
    required LatLng position,
    String? category,
    double? radius,
  }) async {
    if (kDebugMode) print('📡 Modo GPS: Buscando ofertas cercanas...');
    
    final response = await Supabase.instance.client
        .schema('jobs')
        .rpc('get_nearby_offers', params: {
      'user_lat': position.latitude,
      'user_lng': position.longitude,
      'radius_km': radius ?? _radiusKm,
      'p_category_name': category ?? 'Todos',
    });

    final offersData = response as List;
    
    // Normalizar datos planos de la RPC a estructura estándar
    return offersData.map((item) {
      final offer = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
      
      // La RPC devuelve campos planos, los rearmamos en un objeto 'user'
      return {
        ...offer,
        'user': {
          'id': offer['user_id'],
          'firstName': offer['created_by_first_name'] ?? '',
          'lastName': offer['created_by_last_name'] ?? '',
          'imageUrl': offer['user_image_url'] ?? 'https://placehold.co/100',
        }
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _searchOffersStandard({
    String? query,
    String? category,
    String? oficioName,
  }) async {
    if (kDebugMode) print('🔍 Modo Búsqueda: Query="$query", Cat="$category", Oficio="$oficioName"');

    // Construir consulta base trayendo la relación con usuario
    var queryBuilder = Supabase.instance.client
        .schema('jobs')
        .from('offers')
        .select('*, user:user_id(id, firstName, lastName, imageUrl)');

    // Filtro por Categoría
    if (category != null && category != 'Todos') {
      queryBuilder = queryBuilder.eq('category', category);
    }

    // Filtro por Texto (Título o Descripción)
    if (query != null && query.isNotEmpty) {
      queryBuilder = queryBuilder.or('name.ilike.%$query%,description.ilike.%$query%');
    }

    // Filtro por Oficio (Búsqueda en texto)
    if (oficioName != null && oficioName.isNotEmpty) {
      queryBuilder = queryBuilder.or('name.ilike.%$oficioName%,description.ilike.%$oficioName%');
    }

    final response = await queryBuilder.order('created_at', ascending: false);
    final data = List<Map<String, dynamic>>.from(response);

    // Normalizar datos
    return data.map((offer) {
      final userData = offer['user'] ?? {};
      return {
        ...offer,
        'user': {
          'id': userData['id'],
          'firstName': userData['firstName'] ?? '',
          'lastName': userData['lastName'] ?? '',
          'imageUrl': userData['imageUrl'] ?? 'https://placehold.co/100',
        }
      };
    }).toList();
  }

  // --- MÉTODOS ORIGINALES (MANTENIDOS) ---

  Future<String?> createOffer({
    required String userId,
    required String name,
    required String description,
    required int amount,
    required String imageUrl,
    required LatLng position,
    String? category,
  }) async {
    try {
      final response = await Supabase.instance.client
          .schema('jobs')
          .from('offers')
          .insert({
        'user_id': userId,
        'name': name,
        'description': description,
        'amount': amount,
        'image_url': imageUrl,
        'latitud': position.latitude,
        'longitud': position.longitude,
        'category': category,
        'created_at': DateTime.now().toIso8601String(),
      })
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      if (kDebugMode) print('Error al crear oferta: $e');
      return null;
    }
  }

  // ✅ RESTAURADO: Este método estaba en tu archivo original y lo conservamos
  Future<Map<String, dynamic>?> getOfferById(String offerId) async {
    try {
      final response = await Supabase.instance.client
          .schema('jobs')
          .from('offers')
          .select('*, user:user_id(*)')
          .eq('id', offerId)
          .single();

      return response;
    } catch (e) {
      if (kDebugMode) print('Error al obtener detalles de oferta: $e');
      return null;
    }
  }

  // ✅ MANTENIDO: Tu versión RPC que ya funcionaba bien
  Future<List<Map<String, dynamic>>> getUserOffers(String userId) async {
    try {
      final response = await Supabase.instance.client
          .schema('jobs')
          .rpc('get_user_offers', params: {
        'target_user_id': userId,
      });

      final offersData = response as List;
      if (offersData.isEmpty) return [];

      return offersData.map((offer) {
        return {
          'id': offer['id'],
          'name': offer['name'],
          'description': offer['description'],
          'amount': offer['amount'],
          'image_url': offer['image_url'],
          'latitud': offer['latitud'],
          'longitud': offer['longitud'],
          'category': offer['category'],
          'created_at': offer['created_at'],
          'user_id': offer['user_id'],
          'user': {
            'id': offer['user_id'],
            'firstName': offer['created_by_first_name'] ?? '',
            'lastName': offer['created_by_last_name'] ?? '',
            'imageUrl': offer['user_image_url'] ?? 'https://placehold.co/40',
          },
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error getUserOffers: $e');
      return [];
    }
  }

  // ✅ MANTENIDO
  Future<bool> applyToOffer({required String offerId, required String userId}) async {
    try {
      await Supabase.instance.client
          .schema('jobs')
          .from('offer_applicants')
          .upsert({
        'offer_id': offerId,
        'user_id': userId,
        'applied_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}