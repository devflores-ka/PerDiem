import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

class WorkerScheduleScreen extends StatefulWidget {
  const WorkerScheduleScreen({super.key});

  @override
  State<WorkerScheduleScreen> createState() => _WorkerScheduleScreenState();
}

class _WorkerScheduleScreenState extends State<WorkerScheduleScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  // Estructura local para manejar el horario (Lunes=1 ... Domingo=7)
  final List<Map<String, dynamic>> _schedule = [
    {'day': 1, 'isActive': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0)},
    {'day': 2, 'isActive': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0)},
    {'day': 3, 'isActive': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0)},
    {'day': 4, 'isActive': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0)},
    {'day': 5, 'isActive': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0)},
    {'day': 6, 'isActive': false, 'start': const TimeOfDay(hour: 10, minute: 0), 'end': const TimeOfDay(hour: 14, minute: 0)},
    {'day': 7, 'isActive': false, 'start': const TimeOfDay(hour: 10, minute: 0), 'end': const TimeOfDay(hour: 14, minute: 0)},
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .schema('jobs')
          .from('worker_schedules')
          .select()
          .eq('user_id', userId);

      // Mapear datos de BD a la estructura local
      for (var item in data) {
        final dayIndex = (item['day_of_week'] as int) - 1; // Base 0 para la lista
        if (dayIndex >= 0 && dayIndex < 7) {
          _schedule[dayIndex]['isActive'] = item['is_active'];
          _schedule[dayIndex]['start'] = _parseTime(item['start_time']);
          _schedule[dayIndex]['end'] = _parseTime(item['end_time']);
        }
      }
    } catch (e) {
      debugPrint('Error cargando horario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    final userId = _supabase.auth.currentUser!.id;

    try {
      // Preparamos los datos para upsert (insertar o actualizar)
      List<Map<String, dynamic>> updates = [];

      for (var day in _schedule) {
        updates.add({
          'user_id': userId,
          'day_of_week': day['day'],
          'is_active': day['isActive'],
          'start_time': _formatTime(day['start']),
          'end_time': _formatTime(day['end']),
        });
      }

      // Upsert masivo
      await _supabase.schema('jobs').from('worker_schedules').upsert(updates, onConflict: 'user_id, day_of_week');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horario actualizado correctamente'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error guardando: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Helpers de Tiempo
  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm:ss').format(dt);
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final initial = isStart ? _schedule[index]['start'] : _schedule[index]['end'];
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'HORA DE INICIO' : 'HORA DE TÉRMINO',
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _schedule[index]['start'] = picked;
        } else {
          _schedule[index]['end'] = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context){  
    final l10n = AppLocalizations.of(context)!;

    // Mapa auxiliar para obtener el nombre según el número del día
    final Map<int, String> dayNames = {
      1: l10n.monday,    // Asegúrate de tener estas claves en tu archivo .arb
      2: l10n.tuesday,
      3: l10n.wednesday,
      4: l10n.thursday,
      5: l10n.friday,
      6: l10n.saturday,
      7: l10n.sunday,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageScheduleTitle),
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedule.length,
              itemBuilder: (context, index) {
                final day = _schedule[index];
                final dayNumber = day['day'] as int; // Obtenemos el número (1 al 7)
                final dayName = dayNames[dayNumber] ?? 'Día $dayNumber'; // Buscamos la traducción
                final isActive = day['isActive'] as bool;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      children: [
                        // Switch del Día
                        SwitchListTile(
                          title: Text(
                            dayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.blue[800] : Colors.grey,
                            ),
                          ),
                          value: isActive,
                          onChanged: (val) => setState(() => day['isActive'] = val),
                          activeThumbColor: Colors.blue,
                        ),
                        
                        // Selector de Horas (Solo visible si está activo)
                        if (isActive) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildTimeButton(l10n.fromCalendar, day['start'], () => _pickTime(index, true)),
                                const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                                _buildTimeButton(l10n.untilCalendar, day['end'], () => _pickTime(index, false)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveSchedule,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('GUARDAR CAMBIOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay time, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.blue[800])),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
}