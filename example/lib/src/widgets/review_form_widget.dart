// lib/widgets/review_form_widget.dart
import 'package:flutter/material.dart';

import '/l10n/generated/app_localizations.dart';
import '../services/review_service.dart';

class ReviewFormWidget extends StatefulWidget {
  final String reviewedUserId;
  final String proposalId;
  final Function() onReviewSubmitted;
  final String reviewedUserName;

  const ReviewFormWidget({
    super.key,
    required this.reviewedUserId,
    required this.proposalId,
    required this.onReviewSubmitted,
    required this.reviewedUserName,
  });

  @override
  State<ReviewFormWidget> createState() => _ReviewFormWidgetState();
}

class _ReviewFormWidgetState extends State<ReviewFormWidget> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final l10n = AppLocalizations.of(context)!;
    if (_rating == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.plsSelectCalf),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ReviewService.createReview(
        reviewedId: widget.reviewedUserId,
        rating: _rating,
        comment: _commentController.text,
        proposalId: widget.proposalId,
      );

      if (mounted) {
        // Mostrar mensaje de éxito sin error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.succesfulReview),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2), // Reducir duración
          ),
        );

        // Llamar al callback inmediatamente para actualizar el estado
        widget.onReviewSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorSubmitting} $e'),
            backgroundColor: Colors.red,
          ),
        );

        // Solo resetear _isSubmitting si hay error
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l10n.rateOne} ${widget.reviewedUserName}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.howRating,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => IconButton(
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 36,
              ),
              onPressed: _isSubmitting ? null : () {
                setState(() {
                  _rating = index + 1;
                });
              },
            ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.commentOpt,
              border: OutlineInputBorder(),
              hintText: l10n.tellUsExp,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: _isSubmitting ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(l10n.sending),
                  ],
                )
                    : Text(l10n.sendReview),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

// Modal para mostrar el formulario de reseña
class ReviewModal {
  static Future<void> show({
    required BuildContext context,
    required String reviewedUserId,
    required String proposalId,
    required String reviewedUserName,
    Function? onReviewSubmitted,
  }) async => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true, // Permitir cerrar tocando fuera
    enableDrag: true, // Permitir arrastrar para cerrar
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ReviewFormWidget(
              reviewedUserId: reviewedUserId,
              proposalId: proposalId,
              reviewedUserName: reviewedUserName,
              onReviewSubmitted: () {
                // Cerrar el modal inmediatamente
                Navigator.pop(context);

                // Llamar al callback si se proporciona con un pequeño delay
                // para asegurar que el modal se cierre antes de actualizar el estado
                if (onReviewSubmitted != null) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    onReviewSubmitted();
                  });
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}