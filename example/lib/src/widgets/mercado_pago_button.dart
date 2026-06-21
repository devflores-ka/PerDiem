import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class MercadoPagoButton extends StatefulWidget {
  final double monto;
  final String descripcion;
  final String workerId;
  final String proposalId;
  final String payerId;

  const MercadoPagoButton({
    super.key,
    required this.monto,
    required this.descripcion,
    required this.workerId,
    required this.proposalId,
    required this.payerId,
  });

  @override
  State<MercadoPagoButton> createState() => _MercadoPagoButtonState();
}

class _MercadoPagoButtonState extends State<MercadoPagoButton> {
  bool _isLoading = false;
  final PaymentService _paymentService = PaymentService();

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      await _paymentService.generarYAbrirPago(
        proposalId: widget.proposalId,
        titulo: widget.descripcion,
        precio: widget.monto,
        receiverId: widget.workerId,
        payerId: widget.payerId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(top: 12),
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF009EE3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8), // Reducir padding
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 20),
                  SizedBox(width: 8),
                  // ✅ SOLUCIÓN DEL OVERFLOW: Usar Flexible
                  Flexible(
                    child: Text(
                      'Pagar con Mercado Pago',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), // Letra un poco más chica
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
}