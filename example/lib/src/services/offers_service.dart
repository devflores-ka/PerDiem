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

  /// Obtiene ofertas cercanas mediante RPC
  Future<List<Map<String, dynamic>>> getNearbyOffers({
    required LatLng position,
    String? category,
    double? radius,
  }) async {
    try {
      if (kDebugMode) {
        print('Buscando ofertas cercanas con RPC...');
        print('Latitud: ${position.latitude}, Longitud: ${position.longitude}');
        if (category != null && category != 'Todos') {
          print('Filtrando por categoría: $category');
        }
        print('Radio de búsqueda: ${radius ?? _radiusKm} km');
      }

      // Llamada al procedimiento RPC
      final response = await Supabase.instance.client
          .schema('jobs')
          .rpc('get_nearby_offers', params: {
        'user_lat': position.latitude,
        'user_lng': position.longitude,
        'radius_km': radius ?? _radiusKm,
        'p_category_name': category ?? 'Todos',
      },
      );

      if (kDebugMode) {
        print('Respuesta RPC sin procesar: $response');
        print('Tipo de respuesta: ${response.runtimeType}');
      }

      // Convertir respuesta a lista
      final offersData = response as List;

      if (offersData.isEmpty) {
        if (kDebugMode) print('No se encontraron ofertas cercanas.');
        return [];
      }

      // Convertir cada elemento a Map si no lo son ya
      final typedOffersData = offersData.map((item) =>
      item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map),
      ).toList();

      // Crear directamente los datos de usuario desde los campos que vienen en la respuesta
      final enrichedOffers = typedOffersData.map((offer) {
        // Crear objeto de usuario usando los campos que ya vienen en la respuesta
        final user = {
          'id': offer['user_id'],
          'firstName': offer['created_by_first_name'] ?? '',
          'lastName': offer['created_by_last_name'] ?? '',
          'imageUrl': offer['user_image_url'] ?? 'https://ui-avatars.com/api/?name=${offer['created_by_first_name']}&size=100',
        };

        return {
          ...offer,
          'user': user,
        };
      }).toList();

      if (kDebugMode) {
        print('Ofertas enriquecidas: ${enrichedOffers.length}');
      }

      return enrichedOffers;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener ofertas a través de RPC: $e');
      }
      return [];
    }
  }

  /// Crea una nueva oferta de trabajo
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
      if (kDebugMode) {
        print('Error al crear oferta: $e');
      }
      return null;
    }
  }

  /// Obtiene los detalles de una oferta por ID
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
      if (kDebugMode) {
        print('Error al obtener detalles de oferta: $e');
      }
      return null;
    }
  }

  /// Obtiene las ofertas publicadas por un usuario
  Future<List<Map<String, dynamic>>> getUsersOffers(String userId) async {
    try {
      debugPrint('🔍 Obteniendo ofertas del usuario: $userId');

      // Paso 1: Obtener las ofertas del usuario
      final offersResponse = await Supabase.instance.client
          .schema('jobs')
          .from('offers')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      debugPrint('🔍 Ofertas encontradas: ${offersResponse.length}');

      if (offersResponse.isEmpty) {
        debugPrint('❌ No se encontraron ofertas para el usuario');
        return [];
      }

      // Paso 2: Obtener datos del usuario por separado
      final userResponse = await Supabase.instance.client
          .schema('chats')
          .from('users')
          .select('firstName, lastName, imageUrl')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('🔍 Datos del usuario: $userResponse');

      // Paso 3: Combinar los datos
      final userData = userResponse ?? {};

      final transformedOffers = offersResponse.map((offer) {
        debugPrint('🔍 Procesando oferta: ${offer['id']} - ${offer['name']}');

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
            'id': userId,
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'imageUrl': userData['imageUrl'] ?? 'https://placehold.co/40',
          },
        };
      }).toList();

      debugPrint('✅ Ofertas transformadas: ${transformedOffers.length}');
      if (transformedOffers.isNotEmpty) {
        debugPrint('🔍 Primera oferta transformada:');
        debugPrint('   - ID: ${transformedOffers[0]['id']}');
        debugPrint('   - Nombre: ${transformedOffers[0]['name']}');
        debugPrint('   - Usuario: ${transformedOffers[0]['user']['firstName']} ${transformedOffers[0]['user']['lastName']}');
        debugPrint('   - Imagen: ${transformedOffers[0]['image_url']}');
        debugPrint('   - Monto: ${transformedOffers[0]['amount']}');
      }

      return transformedOffers;
    } catch (e, stackTrace) {
      debugPrint('❌ Error obteniendo ofertas del usuario: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  // REEMPLAZAR EL MÉTODO getUsersOffers EN offers_service.dart CON ESTE:

  Future<List<Map<String, dynamic>>> getUserOffers(String userId) async {
    try {
      debugPrint('🔍 === USER OFFERS SERVICE DEBUG ===');
      debugPrint('🆔 Usuario ID: $userId');
      debugPrint('🔧 === CALLING RPC FUNCTION ===');
      debugPrint('🔧 Función: get_user_offers');
      debugPrint('🔧 Parámetros: { target_user_id: $userId }');

      // Llamar a la RPC get_user_offers
      final response = await Supabase.instance.client
          .schema('jobs')
          .rpc('get_user_offers', params: {
        'target_user_id': userId,
      });

      debugPrint('✅ RPC get_user_offers exitosa');
      debugPrint('🎯 === RPC RESPONSE ===');
      debugPrint('📡 Tipo de respuesta: ${response.runtimeType}');
      debugPrint('📡 Es lista: ${response is List}');
      debugPrint('📡 Ofertas encontradas: ${response is List ? response.length : 0}');

      if (response is List && response.isNotEmpty) {
        debugPrint('📡 Primera oferta: ${response[0]}');
      }

      // Convertir respuesta a lista
      final offersData = response as List;

      if (offersData.isEmpty) {
        debugPrint('❌ No se encontraron ofertas para este usuario');
        return [];
      }

      // Transformar los datos para que coincidan con la estructura esperada
      final transformedOffers = offersData.map((offer) {
        debugPrint('🔄 Datos originales: $offer');

        final transformed = {
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

        debugPrint('🔄 Datos transformados: $transformed');
        return transformed;
      }).toList();

      debugPrint('✅ Ofertas transformadas: ${transformedOffers.length}');
      debugPrint('👤 Primera oferta usuario: ${transformedOffers.isNotEmpty ? '${transformedOffers[0]['user']['firstName']} ${transformedOffers[0]['user']['lastName']}' : 'N/A'}');
      debugPrint('💰 Primera oferta monto: ${transformedOffers.isNotEmpty ? transformedOffers[0]['amount'] : 'N/A'}');

      return transformedOffers;
    } catch (e, stackTrace) {
      debugPrint('❌ Error al llamar RPC get_user_offers: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Aplica a una oferta (registra interés)
  Future<bool> applyToOffer({
    required String offerId,
    required String userId,
  }) async {
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
      if (kDebugMode) {
        print('Error al aplicar a oferta: $e');
      }
      return false;
    }
  }
}