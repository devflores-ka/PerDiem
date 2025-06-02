// Archivo: lib/widgets/service_status_widget.dart
import 'package:flutter/material.dart';

import '../services/review_service.dart';
import '../widgets/review_form_widget.dart';
import 'budget_proposal_service.dart';

class ServiceStatusWidget extends StatefulWidget {
  final BudgetProposal proposal;
  final Function onServiceCompleted;
  final Function onReviewSubmitted;

  const ServiceStatusWidget({
    super.key,
    required this.proposal,
    required this.onServiceCompleted,
    required this.onReviewSubmitted,
  });

  @override
  State<ServiceStatusWidget> createState() => _ServiceStatusWidgetState();
}

class _ServiceStatusWidgetState extends State<ServiceStatusWidget> {
  bool _isMarkingCompleted = false;
  String? _userRole;
  bool _hasReviewed = false;
  bool _serviceReadyForReview = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _checkIfServiceReadyForReview();
    _checkIfUserHasReviewed();
  }

  Future<void> _loadUserRole() async {
    final role = await BudgetProposalService.getUserRoleInProposal(widget.proposal.id);
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  Future<void> _checkIfServiceReadyForReview() async {
    final isReady = await BudgetProposalService.isServiceReadyForReview(widget.proposal.id);
    if (mounted) {
      setState(() {
        _serviceReadyForReview = isReady;
      });
    }
  }

  Future<void> _checkIfUserHasReviewed() async {
    // Determinar a quién debe calificar el usuario actual
    final role = await BudgetProposalService.getUserRoleInProposal(widget.proposal.id);
    if (role == null) return;

    final userToReview = role == 'client'
        ? widget.proposal.senderId // Cliente califica al proveedor
        : widget.proposal.receiverId; // Proveedor califica al cliente

    final hasReviewed = await ReviewService.hasReviewedUser(userToReview, widget.proposal.id);
    if (mounted) {
      setState(() {
        _hasReviewed = hasReviewed;
      });
    }
  }

  Future<void> _markAsCompleted() async {
    if (!widget.proposal.isCompleted) {
      setState(() {
        _isMarkingCompleted = true;
      });

      try {
        await BudgetProposalService.markServiceAsCompleted(widget.proposal.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Servicio marcado como completado!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onServiceCompleted();
          await _checkIfServiceReadyForReview();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al marcar como completado: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isMarkingCompleted = false;
          });
        }
      }
    }
  }

  void _showReviewForm() async {
    // Determinar a quién debe calificar el usuario actual
    if (_userRole == null) return;

    final userToReview = _userRole == 'client'
        ? widget.proposal.senderId // Cliente califica al proveedor
        : widget.proposal.receiverId; // Proveedor califica al cliente

    // Obtener el nombre del usuario a calificar
    final reviewedUserName = _userRole == 'client' ? 'Proveedor' : 'Cliente';

    await ReviewModal.show(
      context: context,
      reviewedUserId: userToReview,
      proposalId: widget.proposal.id,
      reviewedUserName: reviewedUserName,
    );

    // Actualizar el estado después de enviar la reseña
    await _checkIfUserHasReviewed();
    widget.onReviewSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.proposal.status != 'accepted') {
      return const SizedBox.shrink(); // No mostrar nada si la propuesta no está aceptada
    }

    return Card(
      margin: const EdgeInsets.all(8),
      color: widget.proposal.isCompleted ? Colors.green[50] : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.proposal.isCompleted
                      ? Icons.check_circle
                      : Icons.pending_actions,
                  color: widget.proposal.isCompleted
                      ? Colors.green
                      : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.proposal.isCompleted
                      ? 'Servicio Completado'
                      : 'Servicio en Progreso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.proposal.isCompleted
                        ? Colors.green[800]
                        : Colors.blue[800],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Mostrar información del presupuesto aceptado
            Text(
              'Presupuesto aceptado: \$${widget.proposal.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),

            if (widget.proposal.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(widget.proposal.description),
              ),

            const SizedBox(height: 12),

            // Botones de acción según el estado
            if (!widget.proposal.isCompleted && _userRole == 'client')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isMarkingCompleted ? null : _markAsCompleted,
                  icon: _isMarkingCompleted
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como Completado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            // Botón para calificar si el servicio está completo y el usuario no ha calificado
            if (_serviceReadyForReview && !_hasReviewed)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showReviewForm,
                    icon: const Icon(Icons.star_border),
                    label: Text('Calificar al ${_userRole == 'client' ? 'Proveedor' : 'Cliente'}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

            // Mostrar mensaje si ya calificó
            if (_serviceReadyForReview && _hasReviewed)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Ya has calificado a este ${_userRole == 'client' ? 'proveedor' : 'cliente'}',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}