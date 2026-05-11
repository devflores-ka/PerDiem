// lib/widgets/service_completion_message.dart
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:perdiem_app/flutter_supabase_chat_core.dart';

import '/l10n/generated/app_localizations.dart';

import '../services/budget_proposal_service.dart';
import '../services/review_service.dart';
import '../widgets/review_form_widget.dart';

class ServiceCompletionMessage extends StatefulWidget {
  final BudgetProposal proposal;
  final Function() onServiceUpdated;

  const ServiceCompletionMessage({
    super.key,
    required this.proposal,
    required this.onServiceUpdated,
  });

  @override
  State<ServiceCompletionMessage> createState() => _ServiceCompletionMessageState();
}

class _ServiceCompletionMessageState extends State<ServiceCompletionMessage> {
  bool _isLoading = false;
  String? _userRole;
  bool _serviceCompleted = false;
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar si el servicio ya está marcado como completado
      _serviceCompleted = widget.proposal.isCompleted;

      // Determinar el rol del usuario actual
      final role = await BudgetProposalService.getUserRoleInProposal(widget.proposal.id);

      // Solo verificar reseñas si tenemos un rol válido
      var hasReviewed = false;
      if (role != null) {
        final userToReview = role == 'client'
            ? widget.proposal.senderId // Cliente califica al proveedor
            : widget.proposal.receiverId; // Proveedor califica al cliente

        // Verificar si el usuario ya ha dejado una reseña
        hasReviewed = await ReviewService.hasReviewedUser(
            userToReview,
            widget.proposal.id,
        );
      }

      if (mounted) {
        setState(() {
          _userRole = role;
          _hasReviewed = hasReviewed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error en _loadInitialData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsCompleted() async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await BudgetProposalService.markServiceAsCompleted(widget.proposal.id);

      // Enviar mensaje al chat informando sobre la finalización
      final message = types.PartialText(
        text: l10n.serviceCompleted,
      );

      await SupabaseChatCore.instance.sendMessage(
        message,
        widget.proposal.roomId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.serviceMarkedCompltd),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _serviceCompleted = true;
          _isLoading = false;
        });

        // Notificar al componente padre que el servicio ha sido actualizado
        widget.onServiceUpdated();
      }
    } catch (e) {
      debugPrint('❌ Error al marcar servicio como completado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorServiceMarkedCompltd} $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsNotCompleted() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Simplemente enviamos un mensaje indicando que el servicio no está completo
      final message = types.PartialText(
        text: l10n.serviceStillIncompltd,
      );

      await SupabaseChatCore.instance.sendMessage(
        message,
        widget.proposal.roomId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.serviceRegNotCompltd),
            backgroundColor: Colors.orange,
          ),
        );

        // Notificar al componente padre
        widget.onServiceUpdated();
      }
    } catch (e) {
      debugPrint('❌ Error al marcar servicio como no completado: $e');
    }
  }

  void _showReviewForm() {
    if (_userRole == null) return;

    final userToReview = _userRole == 'client'
        ? widget.proposal.senderId // Cliente califica al proveedor
        : widget.proposal.receiverId; // Proveedor califica al cliente

    final reviewedUserName = _userRole == 'client' ? 'Proveedor' : 'Cliente';

    ReviewModal.show(
      context: context,
      reviewedUserId: userToReview,
      proposalId: widget.proposal.id,
      reviewedUserName: reviewedUserName,
      onReviewSubmitted: () {
        debugPrint('✅ Reseña enviada, actualizando estado...');
        // Recargar los datos para actualizar el estado de la reseña
        _loadInitialData();
        widget.onServiceUpdated();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Si el servicio ya está completado, mostrar opciones para calificar
    if (_serviceCompleted) {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  l10n.srvCompltd,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mostrar estado de la reseña basado en _hasReviewed
            if (!_hasReviewed) ...[
              // Usuario no ha dejado reseña - mostrar botón para calificar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showReviewForm,
                  icon: const Icon(Icons.star_border),
                  label: Text(l10n.rate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              // Usuario ya ha calificado - mostrar mensaje de agradecimiento
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.thxFTReview,
                        style: TextStyle(
                          color: Colors.amber[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Si el servicio no está completado, mostrar pregunta y opciones
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.serviceDoneYet,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _markAsCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading ? Colors.grey : Colors.green,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(l10n.yes),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _markAsNotCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading ? Colors.grey : Colors.orange,
                  ),
                  child: Text(l10n.no),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}