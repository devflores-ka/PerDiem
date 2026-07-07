// perfil_publico_screen.dart
import 'package:flutter/material.dart';

import '../../services/review_service.dart';
import '../../services/user_service.dart';
import 'package:perdiem_app/flutter_supabase_chat_core.dart';

class PerfilPublicoScreen extends StatefulWidget {
  final String userId;

  const PerfilPublicoScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PerfilPublicoScreen> createState() => _PerfilPublicoScreenState();
}

class _PerfilPublicoScreenState extends State<PerfilPublicoScreen> {
  final UserService _userService = UserService();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _categories = [];
  Map<int, List<Map<String, dynamic>>> _oficios = {};
  UserRating? _rating;

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await _userService.getPublicUserProfile(widget.userId);
      final catData =
          await _userService.getUserCategoriesWithOficios(widget.userId);
      final rating = await ReviewService.getUserRatingOptimized(widget.userId);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _categories =
            List<Map<String, dynamic>>.from(catData['categories'] ?? []);
        _oficios = Map<int, List<Map<String, dynamic>>>.from(
          catData['oficiosPorCategoria'] ?? {},
        );
        _rating = rating;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudo cargar el perfil.';
        _isLoading = false;
      });
    }
  }

  void _showReportDialog() {
    final reasons = <String>[
      'Contenido inapropiado',
      'Acoso o abuso',
      'Spam o estafa',
      'Suplantación de identidad',
      'Otro',
    ];
    String selectedReason = reasons.first;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Reportar usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cuéntanos por qué estás reportando a este usuario:'),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: selectedReason,
                isExpanded: true,
                items: reasons
                    .map(
                      (r) => DropdownMenuItem<String>(
                        value: r,
                        child: Text(r),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedReason = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await SupabaseChatCore.instance.reportUser(
                    widget.userId,
                    selectedReason,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reporte enviado. Gracias por avisarnos.'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo enviar el reporte: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Reportar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: const Text(
          'No volverás a ver mensajes ni conversaciones con esta persona, '
          'y ella tampoco podrá contactarte. ¿Confirmas que quieres bloquearla?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await SupabaseChatCore.instance.blockUser(widget.userId);
                if (!mounted) return;
                // Cierra hasta la raíz (lista de chats), ya que la sala con
                // este usuario va a desaparecer del feed al instante.
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Usuario bloqueado.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No se pudo bloquear al usuario: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final firstName = _profile?['firstName'] as String? ?? '';
    final lastName = _profile?['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final imageUrl = _profile?['imageUrl'] as String?;
    final descripcion = _profile?['descripcion'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(fullName.isEmpty ? 'Perfil' : fullName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _showReportDialog();
              if (value == 'block') _showBlockConfirmation();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined),
                    SizedBox(width: 8),
                    Text('Reportar'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Bloquear', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              backgroundImage:
                  imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl == null || imageUrl.isEmpty
                  ? Icon(Icons.person, size: 50, color: Colors.blue.shade700)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              fullName.isEmpty ? 'Usuario' : fullName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          if (_rating != null && _rating!.totalReviews > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_rating!.averageRating.toStringAsFixed(1)} '
                      '(${_rating!.totalReviews} reseña${_rating!.totalReviews == 1 ? '' : 's'})',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          if (descripcion != null && descripcion.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(descripcion, style: const TextStyle(height: 1.4)),
            ),
          ],
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Especialidades',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._categories.map((category) {
              final oficios = _oficios[category['id']] ?? [];
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
                            category['name'] ?? '',
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
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: oficios
                            .map(
                              (oficio) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Text(
                                  oficio['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          if (_rating != null && _rating!.reviews.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Reseñas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._rating!.reviews.take(5).map((review) {
              final reviewerName =
                  '${review.reviewerData?['firstName'] ?? ''} ${review.reviewerData?['lastName'] ?? ''}'
                      .trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          reviewerName.isEmpty ? 'Usuario' : reviewerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < review.rating ? Icons.star : Icons.star_border,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (review.comment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          review.comment,
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
