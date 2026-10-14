import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';

class HeadacheModuleScreen extends StatefulWidget {
  const HeadacheModuleScreen({super.key});

  @override
  State<HeadacheModuleScreen> createState() => _HeadacheModuleScreenState();
}

class _HeadacheModuleScreenState extends State<HeadacheModuleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Headache Tracker'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Log Entry'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LogEntryTab(
            onSaved: () => _tabController.animateTo(1),
          ),
          const _HeadacheHistoryTab(),
        ],
      ),
    );
  }
}

// ─── Log Entry Tab ─────────────────────────────────────────────────────────

class _LogEntryTab extends StatefulWidget {
  final VoidCallback onSaved;
  const _LogEntryTab({required this.onSaved});

  @override
  State<_LogEntryTab> createState() => _LogEntryTabState();
}

class _LogEntryTabState extends State<_LogEntryTab> {
  static const _types = [
    'Tension',
    'Migraine',
    'Cluster',
    'Other',
    "I don't get headaches"
  ];
  static const _frequencies = [
    'Daily',
    'Few times a week',
    'Weekly',
    'Monthly',
    'Rarely / Never',
  ];
  static const _durations = [
    'Less than 1 hour',
    '1 – 4 hours',
    '4 – 12 hours',
    'More than 12 hours',
  ];

  String? _type;
  String? _frequency;
  String? _duration;
  int _severity = 5;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_type == null || _frequency == null || _duration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.saveHeadacheEntry(
        type: _type!,
        frequency: _frequency!,
        severity: _severity,
        duration: _duration!,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Headache entry saved!'),
          backgroundColor: Colors.green,
        ),
      );
      // Reset
      setState(() {
        _type = null;
        _frequency = null;
        _duration = null;
        _severity = 5;
        _notesController.clear();
      });
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade100, Colors.orange.shade50],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.healing_outlined,
                    size: 36, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Log a headache episode and track patterns over time.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _sectionLabel('1. Headache Type'),
          ..._types.map((t) => _OptionTile(
                label: t,
                selected: _type == t,
                onTap: () => setState(() => _type = t),
              )),
          const SizedBox(height: 18),

          _sectionLabel('2. How Often?'),
          ..._frequencies.map((f) => _OptionTile(
                label: f,
                selected: _frequency == f,
                onTap: () => setState(() => _frequency = f),
              )),
          const SizedBox(height: 18),

          _sectionLabel('3. Pain Level: $_severity / 10'),
          Slider(
            value: _severity.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: _severityColor(_severity),
            label: '$_severity',
            onChanged: (v) => setState(() => _severity = v.toInt()),
          ),
          const SizedBox(height: 18),

          _sectionLabel('4. Duration'),
          ..._durations.map((d) => _OptionTile(
                label: d,
                selected: _duration == d,
                onTap: () => setState(() => _duration = d),
              )),
          const SizedBox(height: 18),

          _sectionLabel('5. Notes (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any triggers, symptoms, or observations...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Entry', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15)),
      );

  Color _severityColor(int v) {
    if (v <= 3) return Colors.green;
    if (v <= 6) return Colors.orange;
    return Colors.red;
  }
}

// ─── History Tab ────────────────────────────────────────────────────────────

class _HeadacheHistoryTab extends StatefulWidget {
  const _HeadacheHistoryTab();

  @override
  State<_HeadacheHistoryTab> createState() => _HeadacheHistoryTabState();
}

class _HeadacheHistoryTabState extends State<_HeadacheHistoryTab> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await FirestoreService.getHeadacheHistory();
    if (!mounted) return;
    setState(() {
      _entries = data;
      _loading = false;
    });
  }

  String _fmt(dynamic ts) {
    if (ts == null) return '';
    try {
      return DateFormat('MMM d, yyyy · hh:mm a').format((ts as Timestamp).toDate());
    } catch (_) {
      return '';
    }
  }

  Color _sev(int v) {
    if (v <= 3) return Colors.green;
    if (v <= 6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.healing_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No entries yet.',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            const Text('Log your first headache episode to see it here.'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        itemBuilder: (_, i) {
          final e = _entries[i];
          final sev = (e['severity'] ?? 5) as int;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: _sev(sev)),
                      const SizedBox(width: 6),
                      Text(e['type'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: _sev(sev).withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Pain: $sev/10',
                            style: TextStyle(
                                color: _sev(sev),
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      '${e['frequency'] ?? ''} · ${e['duration'] ?? ''}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  if ((e['notes'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(e['notes'],
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13,
                            fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 6),
                  Text(_fmt(e['createdAt']),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? Colors.deepPurple.shade50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? Colors.deepPurple : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? Colors.deepPurple : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
