import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

class WorkerStatusSwitch extends StatefulWidget {
  final VoidCallback? onStatusChanged;

  const WorkerStatusSwitch({super.key, this.onStatusChanged});

  @override
  State<WorkerStatusSwitch> createState() => _WorkerStatusSwitchState();
}

class _WorkerStatusSwitchState extends State<WorkerStatusSwitch> {
  bool _isOnline = false;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .schema('chats')
          .from('users')
          .select('is_active')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _isOnline = response['is_active'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Actualizar en Supabase
      await _supabase
          .schema('chats')
          .from('users')
          .update({'is_active': value})
          .eq('id', userId);

      // 2. Actualizar visualmente
      setState(() {
        _isOnline = value;
        _isLoading = false;
      });

      // 3. Notificación visual
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(value ? Icons.visibility : Icons.visibility_off, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value 
                      ? l10n.visibleOnMap 
                      : l10n.hiddenOnMap,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: value ? Colors.green.shade700 : Colors.grey.shade800,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      widget.onStatusChanged?.call();

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const SizedBox(
        width: 40, 
        height: 20, 
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOnline ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.green.shade100 : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isOnline ? Icons.online_prediction : Icons.portable_wifi_off,
                  color: _isOnline ? Colors.green.shade700 : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.workStatus,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _isOnline ? l10n.visibleOnMap : l10n.hiddenOnMap,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOnline ? Colors.green.shade700 : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch.adaptive(
            value: _isOnline,
            onChanged: _toggleStatus,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }
}