import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';

class ProgressHistoryScreen extends StatefulWidget {
  const ProgressHistoryScreen({super.key});

  @override
  State<ProgressHistoryScreen> createState() => ProgressHistoryScreenState();
}

class ProgressHistoryScreenState extends State<ProgressHistoryScreen> {
  String _tab = 'history';
  String _filter = 'All'; // All | DASS-21 | Headache

  // DASS-21 assessments (may also contain headache sub-data)
  List<Map<String, dynamic>> _assessments = [];
  // Standalone headache logs
  List<Map<String, dynamic>> _headaches = [];

  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Called from the bottom-nav shell whenever this tab is (re)selected, so
  /// newly-saved assessments/headaches show up without a manual refresh.
  void reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    // Fetched independently — a failure loading one (e.g. a transient
    // Firestore error) must never blank out data that loaded fine from
    // the other, which is what a combined Future.wait would do.
    List<Map<String, dynamic>> assessments = [];
    List<Map<String, dynamic>> headaches = [];
    String? assessmentError;
    String? headacheError;

    try {
      assessments = await FirestoreService.getAssessmentHistory();
    } catch (e) {
      assessmentError = e.toString();
    }
    try {
      headaches = await FirestoreService.getHeadacheHistory();
    } catch (e) {
      headacheError = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _assessments = assessments;
      _headaches = headaches;
      _loading = false;
      // Only surface an error if BOTH sources failed and there's nothing
      // to show at all — a partial success shouldn't look like a failure.
      _loadError = (assessments.isEmpty && headaches.isEmpty)
          ? (assessmentError ?? headacheError)
          : null;
    });
  }

  // Merge both lists into one timeline sorted newest-first
  List<Map<String, dynamic>> get _merged {
    final tagged = [
      ..._assessments.map((e) => {...e, '_kind': 'dass21'}),
      ..._headaches.map((e) => {...e, '_kind': 'headache'}),
    ];
    tagged.sort((a, b) {
      final ta = a['createdAt'];
      final tb = b['createdAt'];
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return (tb as Timestamp).compareTo(ta as Timestamp);
    });
    if (_filter == 'All') return tagged;
    if (_filter == 'DASS-21') return tagged.where((e) => e['_kind'] == 'dass21').toList();
    return tagged.where((e) => e['_kind'] == 'headache').toList();
  }

  String _fmt(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as Timestamp).toDate();
      return DateFormat('MMM d, yyyy  h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'Normal':        return Colors.green;
      case 'Mild':          return Colors.teal;
      case 'Moderate':      return Colors.orange;
      case 'Severe':        return Colors.red;
      case 'Extremely Severe': return Colors.purple;
      default:              return Colors.grey;
    }
  }

  Color _severityColor(int s) {
    if (s <= 3)  return Colors.green;
    if (s <= 6)  return Colors.orange;
    return Colors.red;
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = _merged;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Progress'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Main tabs ──────────────────────────────────────────────
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'history', label: Text('History')),
                ButtonSegment(value: 'trends',  label: Text('Trends')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 12),

            // ── Filter chips (only in history tab) ─────────────────────
            if (_tab == 'history') ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'DASS-21', 'Headache'].map((f) {
                    final selected = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        selectedColor: Colors.deepPurple.shade100,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Content ────────────────────────────────────────────────
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_loadError != null)
              Expanded(child: _buildError())
            else if (_tab == 'history')
              _buildHistory(items)
            else
              Expanded(child: _TrendsView(assessments: _assessments, headaches: _headaches)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('Could not load your progress.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_chart_outlined,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                _filter == 'All'
                    ? 'No records yet.'
                    : 'No $_filter records yet.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return item['_kind'] == 'dass21'
                ? _Dass21Card(item: item, fmt: _fmt, levelColor: _levelColor)
                : _HeadacheCard(item: item, fmt: _fmt, severityColor: _severityColor);
          },
        ),
      ),
    );
  }
}

// ─── DASS-21 Card ────────────────────────────────────────────────────────────

class _Dass21Card extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final Color Function(String) levelColor;

  const _Dass21Card(
      {required this.item,
      required this.fmt,
      required this.levelColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.deepPurple.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_outlined,
                          size: 13, color: Colors.deepPurple.shade400),
                      const SizedBox(width: 4),
                      Text('DASS-21',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepPurple.shade600,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(fmt(item['createdAt']),
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            // DAS scores
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('D: ${item['depressionScore']}',
                    item['depressionLevel'] ?? '',
                    levelColor(item['depressionLevel'] ?? '')),
                _chip('A: ${item['anxietyScore']}',
                    item['anxietyLevel'] ?? '',
                    levelColor(item['anxietyLevel'] ?? '')),
                _chip('S: ${item['stressScore']}',
                    item['stressLevel'] ?? '',
                    levelColor(item['stressLevel'] ?? '')),
              ],
            ),
            // Headache sub-data if available
            if ((item['headacheType'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.bolt, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Headache: ${item['headacheType']} · ${item['headacheSeverityLabel'] ?? '-'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String score, String level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        '$score · $level',
        style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Standalone Headache Card ─────────────────────────────────────────────────

class _HeadacheCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final Color Function(int) severityColor;

  const _HeadacheCard(
      {required this.item,
      required this.fmt,
      required this.severityColor});

  @override
  Widget build(BuildContext context) {
    final severity = (item['severity'] as num?)?.toInt() ?? 0;
    final color = severityColor(severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 13, color: Colors.orange.shade600),
                      const SizedBox(width: 4),
                      Text('Headache Log',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(fmt(item['createdAt']),
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            // Details row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _tag(Icons.category_outlined,
                    item['type'] ?? '-', Colors.deepPurple),
                _tag(Icons.speed_outlined,
                    'Severity $severity/10', color),
                _tag(Icons.timelapse_outlined,
                    item['duration'] ?? '-', Colors.teal),
                _tag(Icons.repeat_outlined,
                    item['frequency'] ?? '-', Colors.blue),
              ],
            ),
            if ((item['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.notes, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item['notes'],
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Trends View ────────────────────────────────────────────────────────────

class _TrendsView extends StatelessWidget {
  final List<Map<String, dynamic>> assessments;
  final List<Map<String, dynamic>> headaches;
  const _TrendsView({required this.assessments, required this.headaches});

  @override
  Widget build(BuildContext context) {
    if (assessments.isEmpty && headaches.isEmpty) {
      return const Center(child: Text('No data available.'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (assessments.isNotEmpty) ...[
            _sectionHeader('DASS-21 Trends',
                Icons.psychology_outlined, Colors.deepPurple),
            const SizedBox(height: 10),
            ..._buildDassTrends(),
            const SizedBox(height: 20),
          ],
          if (headaches.isNotEmpty) ...[
            _sectionHeader('Headache Trends',
                Icons.bolt, Colors.orange),
            const SizedBox(height: 10),
            ..._buildHeadacheTrends(),
          ],
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${assessments.length} assessment${assessments.length == 1 ? "" : "s"} · '
              '${headaches.length} headache log${headaches.length == 1 ? "" : "s"}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color)),
      ],
    );
  }

  List<Widget> _buildDassTrends() {
    double avg(List<int> l) =>
        l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;

    // Read as num then convert — cloud_firestore_web hands whole numbers
    // back as double (JS has no int/double distinction), so a bare `as
    // int` throws on web even though it works on Android/iOS.
    final dep =
        assessments.map((e) => ((e['depressionScore'] as num?) ?? 0).toInt()).toList();
    final anx =
        assessments.map((e) => ((e['anxietyScore'] as num?) ?? 0).toInt()).toList();
    final str =
        assessments.map((e) => ((e['stressScore'] as num?) ?? 0).toInt()).toList();

    return [
      _TrendCard(label: 'Depression', avg: avg(dep),
          min: dep.reduce((a, b) => a < b ? a : b).toDouble(),
          max: dep.reduce((a, b) => a > b ? a : b).toDouble(),
          color: Colors.blue),
      const SizedBox(height: 10),
      _TrendCard(label: 'Anxiety', avg: avg(anx),
          min: anx.reduce((a, b) => a < b ? a : b).toDouble(),
          max: anx.reduce((a, b) => a > b ? a : b).toDouble(),
          color: Colors.orange),
      const SizedBox(height: 10),
      _TrendCard(label: 'Stress', avg: avg(str),
          min: str.reduce((a, b) => a < b ? a : b).toDouble(),
          max: str.reduce((a, b) => a > b ? a : b).toDouble(),
          color: Colors.red),
    ];
  }

  List<Widget> _buildHeadacheTrends() {
    final severities =
        headaches.map((e) => (e['severity'] as num?)?.toInt() ?? 0).toList();
    double avg(List<int> l) =>
        l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;

    // Type frequency
    final typeCounts = <String, int>{};
    for (final h in headaches) {
      final t = h['type'] ?? 'Unknown';
      typeCounts[t] = (typeCounts[t] ?? 0) + 1;
    }
    final mostCommon = typeCounts.entries.isEmpty
        ? '-'
        : typeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return [
      _TrendCard(label: 'Headache Severity (0–10)',
          avg: avg(severities),
          min: severities.reduce((a, b) => a < b ? a : b).toDouble(),
          max: severities.reduce((a, b) => a > b ? a : b).toDouble(),
          color: Colors.orange),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart, color: Colors.orange),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Most Common Type',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(mostCommon,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ],
        ),
      ),
    ];
  }
}

class _TrendCard extends StatelessWidget {
  final String label;
  final double avg;
  final double min;
  final double max;
  final Color color;

  const _TrendCard({
    required this.label,
    required this.avg,
    required this.min,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('Avg', avg.toStringAsFixed(1), color),
              _Stat('Min', min.toStringAsFixed(0), color),
              _Stat('Max', max.toStringAsFixed(0), color),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
