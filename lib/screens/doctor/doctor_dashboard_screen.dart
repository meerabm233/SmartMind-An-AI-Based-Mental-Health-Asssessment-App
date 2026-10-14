import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../services/firestore_service.dart';
import '../call/call_duration_badge.dart';
import '../call/call_screen.dart';
import '../call/incoming_call_dialog.dart';
import '../onboarding/onboarding_screen.dart';
import 'doctor_profile_edit_screen.dart';
import 'doctor_slots_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _AppointmentsTab(),
      const _ManageSlotsTab(),
      const _DoctorProfileTab(),
    ];

    return IncomingCallListener(
      child: Scaffold(
        body: IndexedStack(index: _navIndex, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) => setState(() => _navIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              label: 'Appointments',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              label: 'Manage Slots',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Appointments Tab ──────────────────────────────────────────────────────────

class _AppointmentsTab extends StatefulWidget {
  const _AppointmentsTab();

  @override
  State<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<_AppointmentsTab> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String _filter = 'all';
  final Map<String, Future<Map<String, dynamic>?>> _assessmentCache = {};

  Future<Map<String, dynamic>?> _assessmentFor(String patientId) {
    return _assessmentCache.putIfAbsent(
        patientId, () => FirestoreService.getLatestAssessmentForPatient(patientId));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FirestoreService.getDoctorAppointments();
      setState(() => _appointments = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _appointments;
    return _appointments
        .where((a) => (a['status'] ?? '') == _filter)
        .toList();
  }

  Future<void> _askStatusUpdate(Map<String, dynamic> a, String status) async {
    final meetingController = TextEditingController(
      text: (a['meetingLink'] ?? '').toString(),
    );
    final noteController = TextEditingController(
      text: (a['doctorNote'] ?? '').toString(),
    );

    final needLink = status == 'confirmed' && (a['mode'] ?? '') == 'Online';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Set as ${status[0].toUpperCase()}${status.substring(1)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (needLink)
                TextField(
                  controller: meetingController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Link',
                    hintText: 'https://meet.google.com/...',
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Doctor Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirestoreService.updateAppointmentByDoctor(
        appointmentId: (a['appointmentId'] ?? a['id']).toString(),
        status: status,
        meetingLink: meetingController.text.trim(),
        doctorNote: noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment updated')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createSlotForPatient() async {
    final emailController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? date;
    String mode = 'Online';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Assign Slot to Patient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Patient Email',
                    hintText: 'patient@email.com',
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 180)),
                    );
                    if (!context.mounted) return;
                    if (pickedDate == null) return;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime == null) return;
                    setStateDialog(() {
                      date = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      date == null
                          ? 'Select Date & Time'
                          : DateFormat('EEE, MMM d yyyy, hh:mm a')
                              .format(date!),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  items: const [
                    DropdownMenuItem(
                        value: 'Online', child: Text('Online')),
                    DropdownMenuItem(
                        value: 'In-Person', child: Text('In-Person')),
                  ],
                  onChanged: (v) =>
                      setStateDialog(() => mode = v ?? 'Online'),
                  decoration: const InputDecoration(labelText: 'Mode'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (emailController.text.trim().isEmpty || date == null) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || date == null) return;

    try {
      await FirestoreService.doctorCreateAppointmentForPatient(
        patientEmail: emailController.text.trim(),
        dateTime: date!,
        mode: mode,
        notes: notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot assigned to patient')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _startCall(Map<String, dynamic> a) async {
    final doctorId = AuthService.currentUser?.uid;
    final patientId = (a['patientId'] ?? '').toString();
    if (doctorId == null || patientId.isEmpty) return;

    final profile = await FirestoreService.getDoctorProfile();
    if (!mounted) return;

    final service = CallService();
    String callId;
    try {
      callId = await service.startCall(
        appointmentId: (a['appointmentId'] ?? a['id']).toString(),
        doctorId: doctorId,
        patientId: patientId,
        doctorName: (profile['name'] ?? 'Doctor').toString(),
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
          otherPartyName: (a['patientName'] ?? 'Patient').toString(),
          isCaller: true,
        ),
      ),
    );
    if (mounted) setState(() {}); // refresh duration badge after the call
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

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final pendingCount =
        _appointments.where((a) => (a['status'] ?? '') == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Requests'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSlotForPatient,
        icon: const Icon(Icons.add),
        label: const Text('Assign Slot'),
      ),
      body: Column(
        children: [
          if (pendingCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.pending_actions, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '$pendingCount pending request${pendingCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                    label: 'All', selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Pending', selected: _filter == 'pending',
                    color: Colors.orange,
                    onTap: () => setState(() => _filter = 'pending')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Confirmed', selected: _filter == 'confirmed',
                    color: Colors.green,
                    onTap: () => setState(() => _filter = 'confirmed')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Completed', selected: _filter == 'completed',
                    color: Colors.blue,
                    onTap: () => setState(() => _filter = 'completed')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Cancelled', selected: _filter == 'cancelled',
                    color: Colors.red,
                    onTap: () => setState(() => _filter = 'cancelled')),
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
                    Icon(Icons.inbox_outlined,
                        size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      _filter == 'all'
                          ? 'No patient appointments yet.'
                          : 'No $_filter appointments.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
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
                    final ts = a['dateTime'];
                    final dt = ts != null
                        ? (ts.toDate() as DateTime)
                        : DateTime.now();
                    final status = (a['status'] ?? 'pending').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.person,
                                      color: Colors.deepPurple.shade300),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (a['patientName'] ?? 'Patient')
                                            .toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        (a['patientEmail'] ?? '').toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status)
                                        .withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _statusColor(status)
                                            .withAlpha(100)),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            _InfoLine(Icons.calendar_today_outlined,
                                DateFormat('EEE, MMM d yyyy, hh:mm a').format(dt)),
                            const SizedBox(height: 6),
                            _InfoLine(
                                a['mode'] == 'Online'
                                    ? Icons.videocam_outlined
                                    : Icons.location_on_outlined,
                                '${a['mode'] ?? ''} Consultation'),
                            if ((a['patientPhone'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _InfoLine(Icons.phone_outlined,
                                  a['patientPhone'].toString()),
                            ],
                            if ((a['notes'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _InfoLine(Icons.notes_outlined,
                                  'Patient note: ${a['notes']}'),
                            ],
                            if ((a['meetingLink'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _InfoLine(Icons.link,
                                  a['meetingLink'].toString()),
                            ],
                            if ((a['doctorNote'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _InfoLine(Icons.note_outlined,
                                  'Your note: ${a['doctorNote']}'),
                            ],
                            if ((a['patientId'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _PatientAssessmentPanel(
                                future: _assessmentFor(a['patientId'].toString()),
                              ),
                            ],
                            if (status == 'confirmed' && a['mode'] == 'Online') ...[
                              const SizedBox(height: 6),
                              CallDurationBadge(
                                appointmentId: (a['appointmentId'] ?? a['id']).toString(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (status == 'confirmed' && a['mode'] == 'Online')
                                  _ActionBtn(
                                    label: 'Video Call',
                                    color: Colors.deepPurple,
                                    icon: Icons.videocam,
                                    onTap: () => _startCall(a),
                                  ),
                                if (status == 'confirmed')
                                  _ActionBtn(
                                    label: 'Complete',
                                    color: Colors.blue,
                                    icon: Icons.done_all,
                                    onTap: () =>
                                        _askStatusUpdate(a, 'completed'),
                                  ),
                                if (status != 'cancelled' &&
                                    status != 'completed')
                                  _ActionBtn(
                                    label: 'Cancel',
                                    color: Colors.red,
                                    icon: Icons.close,
                                    onTap: () =>
                                        _askStatusUpdate(a, 'cancelled'),
                                  ),
                              ],
                            ),
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

// ─── Manage Slots Tab ──────────────────────────────────────────────────────────

class _ManageSlotsTab extends StatefulWidget {
  const _ManageSlotsTab();

  @override
  State<_ManageSlotsTab> createState() => _ManageSlotsTabState();
}

class _ManageSlotsTabState extends State<_ManageSlotsTab> {
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FirestoreService.getDoctorProfile();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Availability'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade50,
                          Colors.deepPurple.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 40, color: Colors.deepPurple.shade400),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Schedule Management',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                  'Manage when patients can book appointments.',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Available Days',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildDaysSection(),
                  const SizedBox(height: 24),

                  const Text('Available Time Slots',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildTimesSection(),
                  const SizedBox(height: 24),

                  _buildStats(),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DoctorSlotsScreen(profile: _profile),
                          ),
                        );
                        if (updated == true) _load();
                      },
                      icon: const Icon(Icons.edit_calendar,
                          color: Colors.white),
                      label: const Text('Edit Slots',
                          style:
                              TextStyle(fontSize: 16, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDaysSection() {
    final days = List<String>.from(_profile['availableDays'] ?? []);
    if (days.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('No available days set. Tap "Edit Slots" to add.'),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days
          .map((d) => Chip(
                label: Text(d),
                backgroundColor: Colors.deepPurple.shade50,
                labelStyle: TextStyle(
                  color: Colors.deepPurple.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTimesSection() {
    final times = List<String>.from(_profile['availableTimes'] ?? []);
    if (times.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('No time slots set. Tap "Edit Slots" to add.'),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: times
          .map((t) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Text(t,
                    style: TextStyle(
                      color: Colors.deepPurple.shade600,
                      fontWeight: FontWeight.w500,
                    )),
              ))
          .toList(),
    );
  }

  Widget _buildStats() {
    final days = List<String>.from(_profile['availableDays'] ?? []);
    final times = List<String>.from(_profile['availableTimes'] ?? []);
    final fee = (_profile['consultationFee'] ?? 0).toDouble();
    final online = _profile['isOnlineAvailable'] ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatTile('Days', '${days.length}', Colors.deepPurple),
              const SizedBox(width: 12),
              _StatTile('Slots', '${times.length}', Colors.blue),
              const SizedBox(width: 12),
              _StatTile(
                  'Fee', 'PKR ${fee.toStringAsFixed(0)}', Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                online ? Icons.videocam : Icons.videocam_off,
                size: 16,
                color: online ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                online ? 'Online consultations enabled' : 'Online consultations disabled',
                style: TextStyle(
                  fontSize: 13,
                  color: online ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Doctor Profile Tab ─────────────────────────────────────────────────────────

class _DoctorProfileTab extends StatefulWidget {
  const _DoctorProfileTab();

  @override
  State<_DoctorProfileTab> createState() => _DoctorProfileTabState();
}

class _DoctorProfileTabState extends State<_DoctorProfileTab> {
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FirestoreService.getDoctorProfile();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DoctorProfileEditScreen(profile: _profile),
                ),
              );
              if (updated == true) _load();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile.isEmpty
              ? const Center(child: Text('Profile not found.'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.deepPurple.shade400,
                              Colors.deepPurple.shade200,
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                              ),
                              child: const Icon(Icons.person,
                                  size: 50, color: Colors.deepPurple),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _profile['name'] ?? 'Doctor',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profile['specialty'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profile['email'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _ProfileStat(
                                  icon: Icons.star,
                                  color: Colors.amber,
                                  value:
                                      '${(_profile['rating'] ?? 0).toDouble().toStringAsFixed(1)}',
                                  label: 'Rating',
                                ),
                                _ProfileStat(
                                  icon: Icons.people_outline,
                                  color: Colors.blue,
                                  value:
                                      '${_profile['patients'] ?? 0}',
                                  label: 'Patients',
                                ),
                                _ProfileStat(
                                  icon: Icons.work_outline,
                                  color: Colors.green,
                                  value:
                                      '${_profile['experience'] ?? 0} yrs',
                                  label: 'Experience',
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _ProfileTile(Icons.school_outlined,
                                'Qualification', _profile['qualification'] ?? '-'),
                            _ProfileTile(Icons.local_hospital_outlined,
                                'Hospital', _profile['hospital'] ?? '-'),
                            _ProfileTile(Icons.location_on_outlined,
                                'Location', _profile['location'] ?? '-'),
                            _ProfileTile(Icons.phone_outlined, 'Phone',
                                _profile['phone'] ?? '-'),
                            _ProfileTile(
                                Icons.payments_outlined,
                                'Consultation Fee',
                                'PKR ${(_profile['consultationFee'] ?? 0).toDouble().toStringAsFixed(0)}'),
                            if ((_profile['bio'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('About',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 6),
                                    Text(
                                      _profile['bio'].toString(),
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _logout,
                                icon: const Icon(Icons.logout,
                                    color: Colors.red),
                                label: const Text('Logout',
                                    style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────────

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
          border: Border.all(color: selected ? color : Colors.grey.shade300),
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

/// Shows the patient's latest DASS-21/headache self-assessment, so the
/// doctor has clinical context before the consultation.
class _PatientAssessmentPanel extends StatelessWidget {
  final Future<Map<String, dynamic>?> future;
  const _PatientAssessmentPanel({required this.future});

  Color _levelColor(String level) {
    switch (level) {
      case 'Normal':
        return Colors.green;
      case 'Mild':
        return Colors.lightGreen;
      case 'Moderate':
        return Colors.orange;
      case 'Severe':
        return Colors.deepOrange;
      case 'Extremely Severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final a = snap.data;
        if (a == null) return const SizedBox.shrink();

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: const Icon(Icons.assignment_outlined,
                size: 18, color: Colors.deepPurple),
            title: const Text('Patient Self-Assessment',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AssessmentChip('Depression',
                      (a['depressionLevel'] ?? '-').toString(), _levelColor),
                  _AssessmentChip('Anxiety',
                      (a['anxietyLevel'] ?? '-').toString(), _levelColor),
                  _AssessmentChip('Stress',
                      (a['stressLevel'] ?? '-').toString(), _levelColor),
                ],
              ),
              if ((a['headacheType'] ?? '').toString().isNotEmpty &&
                  a['headacheType'] != "I don't get headaches") ...[
                const SizedBox(height: 8),
                _InfoLine(
                  Icons.sick_outlined,
                  'Headache: ${a['headacheType']} · ${a['headacheFrequency'] ?? ''} · '
                  '${a['headacheSeverityLabel'] ?? ''} (${a['headacheSeverity'] ?? '-'}/10) · '
                  '${a['headacheDuration'] ?? ''}',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AssessmentChip extends StatelessWidget {
  final String label;
  final String level;
  final Color Function(String) colorFor;
  const _AssessmentChip(this.label, this.level, this.colorFor);

  @override
  Widget build(BuildContext context) {
    final color = colorFor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text('$label: $level',
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withAlpha(100)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _ProfileStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple.shade300),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
