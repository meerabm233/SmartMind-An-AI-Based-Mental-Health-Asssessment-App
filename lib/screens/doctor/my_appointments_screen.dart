import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../services/firestore_service.dart';
import '../call/call_duration_badge.dart';
import '../call/call_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FirestoreService.getMyAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _appointments;
    return _appointments
        .where((a) => (a['status'] ?? '') == _filter)
        .toList();
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as Timestamp).toDate();
      return DateFormat('EEE, MMM d yyyy · hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule;
    }
  }

  Future<void> _startCall(Map<String, dynamic> a) async {
    final patientId = AuthService.currentUser?.uid;
    final doctorId = (a['doctorId'] ?? '').toString();
    if (patientId == null || doctorId.isEmpty) return;

    final service = CallService();
    String callId;
    try {
      callId = await service.startCall(
        appointmentId: (a['appointmentId'] ?? a['id']).toString(),
        doctorId: doctorId,
        patientId: patientId,
        doctorName: (a['doctorName'] ?? 'Doctor').toString(),
        patientName: (a['patientName'] ?? 'Patient').toString(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start call: $e'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          service: service,
          callId: callId,
          otherPartyName: (a['doctorName'] ?? 'Doctor').toString(),
          isCaller: true,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pending',
                  selected: _filter == 'pending',
                  color: Colors.orange,
                  onTap: () => setState(() => _filter = 'pending'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Confirmed',
                  selected: _filter == 'confirmed',
                  color: Colors.green,
                  onTap: () => setState(() => _filter = 'confirmed'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Completed',
                  selected: _filter == 'completed',
                  color: Colors.blue,
                  onTap: () => setState(() => _filter = 'completed'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Cancelled',
                  selected: _filter == 'cancelled',
                  color: Colors.red,
                  onTap: () => setState(() => _filter = 'cancelled'),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      _filter == 'all'
                          ? 'No appointments yet.'
                          : 'No $_filter appointments.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 6),
                    const Text('Book a doctor to see appointments here.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final a = items[i];
                    final status = (a['status'] ?? 'pending').toString();
                    final sColor = _statusColor(status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.person,
                                      color: Colors.deepPurple.shade300),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (a['doctorName'] ?? 'Doctor')
                                            .toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        (a['specialty'] ?? '').toString(),
                                        style: TextStyle(
                                          color: Colors.deepPurple.shade400,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: sColor.withAlpha(100)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_statusIcon(status),
                                          size: 14, color: sColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        status[0].toUpperCase() +
                                            status.substring(1),
                                        style: TextStyle(
                                          color: sColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            _DetailRow(
                              icon: Icons.calendar_today_outlined,
                              label: _fmtDate(a['dateTime']),
                            ),
                            const SizedBox(height: 8),
                            _DetailRow(
                              icon: a['mode'] == 'Online'
                                  ? Icons.videocam_outlined
                                  : Icons.location_on_outlined,
                              label:
                                  '${a['mode'] ?? 'Online'} Consultation',
                            ),
                            if ((a['meetingLink'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _DetailRow(
                                icon: Icons.link,
                                label: a['meetingLink'].toString(),
                                color: Colors.blue,
                              ),
                            ],
                            if ((a['doctorNote'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _DetailRow(
                                icon: Icons.note_outlined,
                                label:
                                    'Doctor note: ${a['doctorNote']}',
                              ),
                            ],
                            if ((a['notes'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _DetailRow(
                                icon: Icons.notes_outlined,
                                label: 'Your note: ${a['notes']}',
                              ),
                            ],
                            if (status == 'confirmed' && a['mode'] == 'Online') ...[
                              const SizedBox(height: 8),
                              CallDurationBadge(
                                appointmentId: (a['appointmentId'] ?? a['id']).toString(),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _startCall(a),
                                  icon: const Icon(Icons.videocam, size: 18),
                                  label: const Text('Video Call Doctor'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = Colors.deepPurple,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color ?? Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
