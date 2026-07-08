import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:perdiem_app/flutter_supabase_chat_core.dart';

/// Pantalla de "Usuarios bloqueados y reportes enviados".
/// Muestra dos secciones:
///  - Bloqueados: usuarios que el usuario actual bloqueó, con opción de
///    desbloquear.
///  - Reportes enviados: historial de reportes que el usuario hizo
///    (a usuarios o a mensajes puntuales), de solo lectura.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoadingBlocked = true;
  bool _isLoadingReports = true;
  String? _blockedError;
  String? _reportsError;

  List<Map<String, dynamic>> _blockedUsers = [];
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBlockedUsers();
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoadingBlocked = true;
      _blockedError = null;
    });
    try {
      final data = await _supabase
          .schema('chats')
          .from('blocked_users')
          .select(
            'blocked_id, created_at, blocked:blocked_id(id, firstName, lastName, imageUrl)',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _blockedUsers = List<Map<String, dynamic>>.from(data);
        _isLoadingBlocked = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _blockedError = 'No se pudo cargar la lista de bloqueados.';
        _isLoadingBlocked = false;
      });
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
      _reportsError = null;
    });
    try {
      final data = await _supabase
          .schema('chats')
          .from('reports')
          .select(
            'id, reason, status, created_at, reported_user_id, '
            'reported:reported_user_id(firstName, lastName, imageUrl)',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _reports = List<Map<String, dynamic>>.from(data);
        _isLoadingReports = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportsError = 'No se pudo cargar el historial de reportes.';
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _confirmUnblock(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desbloquear usuario'),
        content: Text(
          '¿Quieres desbloquear a $name? Vas a volver a ver sus mensajes '
          'y podrán contactarse de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseChatCore.instance.unblockUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name fue desbloqueado.')),
      );
      _loadBlockedUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo desbloquear: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String isoOrTimestamp) {
    DateTime? date;
    try {
      date = DateTime.parse(isoOrTimestamp);
    } catch (_) {
      return isoOrTimestamp;
    }
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  String _fullName(Map<String, dynamic>? user) {
    if (user == null) return 'Usuario eliminado';
    final first = user['firstName'] as String? ?? '';
    final last = user['lastName'] as String? ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Usuario' : name;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Bloqueados y reportes'),
          foregroundColor: Colors.black,
          elevation: 2,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Bloqueados'),
              Tab(text: 'Reportes enviados'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBlockedTab(),
            _buildReportsTab(),
          ],
        ),
      );

  Widget _buildBlockedTab() {
    if (_isLoadingBlocked) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_blockedError != null) {
      return _buildErrorState(_blockedError!, _loadBlockedUsers);
    }
    if (_blockedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.block,
        message: 'No has bloqueado a ningún usuario.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final entry = _blockedUsers[index];
          final user = entry['blocked'] as Map<String, dynamic>?;
          final name = _fullName(user);
          final imageUrl = user?['imageUrl'] as String?;
          final blockedId = entry['blocked_id'] as String;
          final createdAt = entry['created_at'] as String?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade100,
                backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl == null || imageUrl.isEmpty
                    ? Icon(Icons.person, color: Colors.blue.shade700)
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: createdAt != null
                  ? Text('Bloqueado el ${_formatDate(createdAt)}')
                  : null,
              trailing: TextButton(
                onPressed: () => _confirmUnblock(blockedId, name),
                child: const Text('Desbloquear'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportsError != null) {
      return _buildErrorState(_reportsError!, _loadReports);
    }
    if (_reports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.flag_outlined,
        message: 'No has enviado reportes.',
      );
    }

    const statusLabels = {
      'pending': 'Pendiente de revisión',
      'reviewed': 'Revisado',
      'dismissed': 'Descartado',
    };
    const statusColors = {
      'pending': Colors.orange,
      'reviewed': Colors.green,
      'dismissed': Colors.grey,
    };

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final entry = _reports[index];
          final reportedUser = entry['reported'] as Map<String, dynamic>?;
          final name = _fullName(reportedUser);
          final reason = entry['reason'] as String? ?? '';
          final status = entry['status'] as String? ?? 'pending';
          final createdAt = entry['created_at'] as String?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.grey.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (statusColors[status] ?? Colors.grey)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabels[status] ?? status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColors[status] ?? Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Motivo: $reason', style: TextStyle(color: Colors.grey.shade800)),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );

  Widget _buildErrorState(String message, Future<void> Function() onRetry) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}