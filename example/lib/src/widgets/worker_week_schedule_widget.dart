import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class WorkerWeekScheduleWidget extends StatefulWidget {
  final String userId;

  const WorkerWeekScheduleWidget({super.key, required this.userId});

  @override
  State<WorkerWeekScheduleWidget> createState() => _WorkerWeekScheduleWidgetState();
}

class _WorkerWeekScheduleWidgetState extends State<WorkerWeekScheduleWidget> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _baseSchedule = [];
  List<Map<String, dynamic>> _bookedProposals = [];
  bool _isLoading = true;
  bool _hasSchedule = false;

  late List<DateTime> _next7Days;

  @override
  void initState() {
    super.initState();
    // Generar los próximos 7 días (empezando desde hoy)
    final now = DateTime.now();
    _next7Days = List.generate(7, (i) => now.add(Duration(days: i)));
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Cargar horario base
      final scheduleData = await _supabase
          .schema('jobs')
          .from('worker_schedules')
          .select()
          .eq('user_id', widget.userId)
          .eq('is_active', true);

      // 2. Cargar reservas de los próximos 7 días
      final startDate = DateTime(_next7Days.first.year, _next7Days.first.month, _next7Days.first.day).toUtc().toIso8601String();
      final endDate = _next7Days.last.add(const Duration(days: 1)).toUtc().toIso8601String();

      final bookingsData = await _supabase
          .schema('jobs')
          .from('budget_proposals')
          .select('scheduled_date')
          .eq('sender_id', widget.userId)
          .eq('status', 'accepted')
          .not('scheduled_date', 'is', null)
          .gte('scheduled_date', startDate)
          .lt('scheduled_date', endDate);

      if (mounted) {
        setState(() {
          _baseSchedule = List<Map<String, dynamic>>.from(scheduleData);
          _bookedProposals = List<Map<String, dynamic>>.from(bookingsData);
          _hasSchedule = _baseSchedule.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando horario público: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _countBookingsForDate(DateTime date) {
    int count = 0;
    for (var booking in _bookedProposals) {
      final scheduled = DateTime.parse(booking['scheduled_date']).toLocal();
      if (scheduled.year == date.year && scheduled.month == date.month && scheduled.day == date.day) {
        count++;
      }
    }
    return count;
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) { return timeStr; }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
    
    if (!_hasSchedule) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 0,
        color: Colors.grey[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Text('Disponibilidad Semanal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Este trabajador no ha indicado sus horarios de atención.', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Próximos 7 días', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 95, // Más alto para acomodar el estado
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _next7Days.length,
                separatorBuilder: (c, i) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final targetDate = _next7Days[index];
                  final dayNum = targetDate.weekday; // 1=Lun, 7=Dom
                  
                  // ¿Trabaja este día?
                  final daySchedule = _baseSchedule.firstWhere((s) => s['day_of_week'] == dayNum, orElse: () => {});
                  final isWorkingDay = daySchedule.isNotEmpty;

                  // Calcular cupos
                  bool isFull = false;
                  if (isWorkingDay) {
                    final startHour = int.parse(daySchedule['start_time'].split(':')[0]);
                    final endHour = int.parse(daySchedule['end_time'].split(':')[0]);
                    final maxSlots = (endHour - startHour).abs(); // Asumiendo 1 hr por trabajo
                    final bookings = _countBookingsForDate(targetDate);
                    isFull = bookings >= maxSlots;
                  }

                  final bool isToday = index == 0;

                  return Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: !isWorkingDay ? Colors.grey.shade100 : (isFull ? Colors.red.shade50 : Colors.green.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !isWorkingDay ? Colors.grey.shade300 : (isFull ? Colors.red.shade200 : Colors.green.shade300),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E', 'es_ES').format(targetDate).toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: !isWorkingDay ? Colors.grey : Colors.black87),
                        ),
                        Text(
                          '${targetDate.day}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: !isWorkingDay ? Colors.grey : Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        if (!isWorkingDay)
                          const Icon(Icons.close, size: 14, color: Colors.grey)
                        else if (isFull)
                          const Text('Lleno', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))
                        else
                          const Text('Libre', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}