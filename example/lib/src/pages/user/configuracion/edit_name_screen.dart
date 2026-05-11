import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditNameScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final VoidCallback? onProfileUpdated;

  const EditNameScreen({
    super.key,
    this.userProfile,
    this.onProfileUpdated,
  });

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _canChangeName = false;
  int _changesThisYear = 0;
  DateTime? _lastChangeDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Cargar datos actuales
    _firstNameController.text = widget.userProfile?['firstName'] ?? '';
    _lastNameController.text = widget.userProfile?['lastName'] ?? '';

    await _checkNameChangeEligibility();
    setState(() => _isLoading = false);
  }

  Future<void> _checkNameChangeEligibility() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Consultar historial de cambios de nombre
      final response = await supabase
          .schema('chats')
          .from('name_changes')
          .select('changed_at')
          .eq('user_id', userId)
          .order('changed_at', ascending: false);

      final changes = response as List<dynamic>;
      final now = DateTime.now();

      // Contar cambios en el último año
      _changesThisYear = changes.where((change) {
        final changeDate = DateTime.parse(change['changed_at']);
        return now.difference(changeDate).inDays <= 365;
      }).length;

      // Verificar último cambio
      if (changes.isNotEmpty) {
        _lastChangeDate = DateTime.parse(changes.first['changed_at']);
        final daysSinceLastChange = now.difference(_lastChangeDate!).inDays;

        if (daysSinceLastChange < 90) {
          _canChangeName = false;
          final daysRemaining = 90 - daysSinceLastChange;
          _errorMessage = 'Debes esperar $daysRemaining días más para cambiar tu nombre';
        } else if (_changesThisYear >= 3) {
          _canChangeName = false;
          _errorMessage = 'Has alcanzado el límite de 3 cambios por año';
        } else {
          _canChangeName = true;
        }
      } else {
        _canChangeName = true;
      }

    } catch (e) {
      _errorMessage = 'Error al verificar elegibilidad: $e';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Editar nombre'),
        foregroundColor: Colors.black,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información de restricciones
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Restricciones',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Solo puedes cambiar tu nombre cada 3 meses'),
                    const Text('• Máximo 3 cambios por año'),
                    Text('• Cambios realizados este año: $_changesThisYear/3'),
                    if (_lastChangeDate != null)
                      Text('• Último cambio: ${_formatDate(_lastChangeDate!)}'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Estado de elegibilidad
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _canChangeName ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _canChangeName ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _canChangeName ? Icons.check_circle : Icons.cancel,
                      color: _canChangeName ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _canChangeName
                            ? 'Puedes cambiar tu nombre'
                            : _errorMessage ?? 'No puedes cambiar tu nombre',
                        style: TextStyle(
                          color: _canChangeName ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Formulario
              TextFormField(
                controller: _firstNameController,
                enabled: _canChangeName,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _canChangeName ? null : Colors.grey.shade100,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres';
                  }
                  if (value.trim().length > 50) {
                    return 'El nombre no puede exceder 50 caracteres';
                  }
                  if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(value.trim())) {
                    return 'El nombre solo puede contener letras y espacios';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _lastNameController,
                enabled: _canChangeName,
                decoration: InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _canChangeName ? null : Colors.grey.shade100,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El apellido es requerido';
                  }
                  if (value.trim().length < 2) {
                    return 'El apellido debe tener al menos 2 caracteres';
                  }
                  if (value.trim().length > 50) {
                    return 'El apellido no puede exceder 50 caracteres';
                  }
                  if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(value.trim())) {
                    return 'El apellido solo puede contener letras y espacios';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canChangeName && !_isSaving ? _saveName : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text('Guardar cambios'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

  // Código Flutter actualizado (solo el método _saveName, ya que el trigger se encargará de actualizar users)
  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // ELIMINAR la actualización manual de users - el trigger lo hará automáticamente
      // Ya no necesitamos esto porque el trigger se encarga:
      /*
    await supabase
        .schema('chats')
        .from('users')
        .update({
      'firstName': firstName,
      'lastName': lastName,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    })
        .eq('id', userId);
    */

      // Solo registrar cambio de nombre - el trigger actualizará users automáticamente
      await supabase
          .schema('chats')
          .from('name_changes')
          .insert({
        'user_id': userId,
        'old_first_name': widget.userProfile?['firstName'],
        'old_last_name': widget.userProfile?['lastName'],
        'new_first_name': firstName,
        'new_last_name': lastName,
        'changed_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nombre actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Callback para actualizar perfil
        widget.onProfileUpdated?.call();

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar nombre: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}