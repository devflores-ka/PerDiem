// lib/widgets/user_offers_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/l10n/generated/app_localizations.dart';

import '../services/offers_service.dart';
import '../utils/ofertas/detalle_oferta.dart';
import '../utils/tarjetas.dart';

class UserOffersWidget extends StatefulWidget {
  final String userId;

  const UserOffersWidget({
    super.key,
    required this.userId,
  });

  @override
  State<UserOffersWidget> createState() => _UserOffersWidgetState();
}

class _UserOffersWidgetState extends State<UserOffersWidget> {
  // Estado para las ofertas del usuario
  List<TarjetaServicio> _userOffers = [];
  List<Map<String, double>> _userOfferCoordinates = [];
  List<String> _userOfferIds = [];
  List<String> _userOfferNames = [];
  List<String> _userOfferUserIds = [];
  bool _isLoadingOffers = true;

  @override
  void initState() {
    super.initState();
    _loadUserOffers();
  }

  Future<void> _loadUserOffers() async {
    setState(() => _isLoadingOffers = true);

    try {
      debugPrint('🔍 Cargando ofertas del usuario: ${widget.userId}');

      final offersService = OffersService();

      // Obtener ofertas del usuario específico
      final userOffers = await offersService.getUserOffers(widget.userId);

      final tarjetas = <TarjetaServicio>[];
      final coordenadas = <Map<String, double>>[];
      final ids = <String>[];
      final names = <String>[];
      final userIds = <String>[]; // <--- 2. LISTA TEMPORAL

      for (var oferta in userOffers) {
        final user = oferta['user'] ?? {};

        tarjetas.add(TarjetaServicio(
          imagenUrl: oferta['image_url'] ?? 'https://placehold.co/150',
          descripcion: oferta['description'] ?? '',
          presupuesto: (oferta['amount'] is double)
              ? oferta['amount']
              : (oferta['amount'] ?? 0).toDouble(),
          nombreUsuario: '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
          avatarUrl: user['imageUrl'] ?? 'https://placehold.co/40',
          calificacion: 4.9, 
          numResenas: '2.5k', 
          esFavorito: false,
          ),
        );

        coordenadas.add({
          'latitud': oferta['latitud'] ?? 0.0,
          'longitud': oferta['longitud'] ?? 0.0,
        });
        ids.add(oferta['id'].toString());
        names.add(oferta['name']?.toString() ?? '');
        userIds.add(user['id']?.toString() ?? ''); // <--- GUARDAMOS EL USER ID
      }

      if (mounted) {
        setState(() {
          _userOffers = tarjetas;
          _userOfferCoordinates = coordenadas;
          _userOfferIds = ids;
          _userOfferNames = names;
          _userOfferUserIds = userIds; // <--- GUARDAMOS EN EL ESTADO
          _isLoadingOffers = false;
        });

        debugPrint('✅ Ofertas del usuario cargadas: ${_userOffers.length}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando ofertas del usuario: $e');
      if (mounted) {
        setState(() => _isLoadingOffers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingOffers) {
      return Column(
        children: [
          SizedBox(height: 20),
          Text(l10n.myServices, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 20),
        ],
      );
    }

    if (_userOffers.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Text(l10n.myServices, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                l10n.noServiceOnAir,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(l10n.myServices, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),

        // Banner inicial de sponsor
        _buildSponsorBanner(),

        // Lista de ofertas
        ...List.generate(
          (_userOffers.length / 2).ceil(),
              (rowIndex) {
            final startIndex = rowIndex * 2;

            // Cada 2 filas (4 tarjetas), insertar un banner
            final widgets = <Widget>[];

            if (rowIndex > 0 && rowIndex % 2 == 0) {
              widgets.add(_buildSponsorBanner());
            }

            widgets.add(_buildOfferRow(startIndex));

            return Column(children: widgets);
          },
        ),
      ],
    );
  }

  Widget _buildOfferRow(int startIndex) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Primera tarjeta
          Expanded(
            child: _buildCompactOfferCard(startIndex),
          ),
          const SizedBox(width: 8),
          // Segunda tarjeta (si existe)
          Expanded(
            child: startIndex + 1 < _userOffers.length
                ? _buildCompactOfferCard(startIndex + 1)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

  Widget _buildCompactOfferCard(int index) {
    final oferta = _userOffers[index];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetalleOferta(
              imagenUrl: oferta.imagenUrl,
              descripcion: oferta.descripcion,
              presupuesto: oferta.presupuesto,
              nombreUsuario: oferta.nombreUsuario,
              avatarUrl: oferta.avatarUrl,
              calificacion: oferta.calificacion,
              numResenas: oferta.numResenas,
              latitud: _userOfferCoordinates[index]['latitud']!,
              longitud: _userOfferCoordinates[index]['longitud']!,
              offerId: _userOfferIds[index],
              offerName: _userOfferNames[index],
              userId: _userOfferUserIds[index], // <--- 3. AQUÍ PASAMOS EL ID CORRECTO
              mostrarCalificacion: true,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen estandarizada
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Image.network(
                  oferta.imagenUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
            ),

            // Contenido de la tarjeta
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Usuario
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(oferta.avatarUrl),
                        radius: 12,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          oferta.nombreUsuario,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Descripción
                  Text(
                    oferta.descripcion,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Espacio para futura calificación si es necesario
                      const SizedBox(),

                      // Precio en formato chileno
                      Text(
                        '${NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0).format(oferta.presupuesto)} CLP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsorBanner() => Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'SPONSOR',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
}