import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class DoctorSlotsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const DoctorSlotsScreen({super.key, required this.profile});

  @override
  State<DoctorSlotsScreen> createState() => _DoctorSlotsScreenState();
}

class _DoctorSlotsScreenState extends State<DoctorSlotsScreen> {
  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late List<String> _selectedDays;
  late List<String> _selectedTimes;
  bool _saving = false;

  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDays =
        List<String>.from(widget.profile['availableDays'] ?? []);
    _selectedTimes =
        List<String>.from(widget.profile['availableTimes'] ?? []);
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one available day.')),
      );
      return;
    }
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one time slot.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.updateDoctorSlots(
        availableDays: _selectedDays,
        availableTimes: _selectedTimes..sort(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slots updated!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTimeSlot() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (_selectedTimes.contains(formatted)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time slot already exists.')),
      );
      return;
    }
    setState(() {
      _selectedTimes.add(formatted);
      _selectedTimes.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Slots')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
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
                  Icon(Icons.info_outline,
                      color: Colors.deepPurple.shade400),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Set the days and times when patients can book appointments with you.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Available Days',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allDays.map((day) {
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: selected,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                  selectedColor: Colors.deepPurple.shade100,
                  checkmarkColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? Colors.deepPurple.shade800
                        : Colors.black87,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                const Text('Available Time Slots',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addTimeSlot,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Slot'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedTimes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.access_time,
                        size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No time slots yet.',
                        style: TextStyle(color: Colors.grey.shade500)),
                    const Text('Tap "Add Slot" to add available times.'),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedTimes.map((t) {
                  return Chip(
                    label: Text(t),
                    backgroundColor: Colors.deepPurple.shade50,
                    labelStyle: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    deleteIcon: Icon(Icons.close,
                        size: 16, color: Colors.deepPurple.shade400),
                    onDeleted: () {
                      setState(() => _selectedTimes.remove(t));
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Slots',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
