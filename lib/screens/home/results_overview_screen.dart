import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/assessment_result.dart';
import '../../services/firestore_service.dart';
import 'recommendations_screen.dart';
import 'results_detailed_screen.dart';

class ResultsOverviewScreen extends StatefulWidget {
  /// When passed directly from an assessment flow, show that result immediately.
  final AssessmentResult? result;

  const ResultsOverviewScreen({super.key, this.result});

  @override
  State<ResultsOverviewScreen> createState() => _ResultsOverviewScreenState();
}

class _ResultsOverviewScreenState extends State<ResultsOverviewScreen> {
  bool _loading = true;

  // Latest DASS-21 assessment fields
  int? _dep, _anx, _str;
  String _depLevel = '', _anxLevel = '', _strLevel = '';
  String _assessmentDate = '';

  // Headache from the assessment (combined)
  String _headacheType = '';
  String _headacheSeverityLabel = '';

  // Latest standalone headache entry
  Map<String, dynamic>? _latestHeadache;

  // Store the original result for passing to detail/recommendation screens
  AssessmentResult? _originalResult;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      try {
        _originalResult = widget.result;
        _populateFromResult(widget.result!);
        _loading = false;
      } catch (e) {
        _loading = false;
        _loadError = e.toString();
      }
    } else {
      _loadLatest();
    }
  }

  void _populateFromResult(AssessmentResult r) {
    _dep = r.depressionScore;
    _anx = r.anxietyScore;
    _str = r.stressScore;
    _depLevel = r.depressionLevel;
    _anxLevel = r.anxietyLevel;
    _strLevel = r.stressLevel;
    _headacheType = r.headacheType;
    _headacheSeverityLabel = r.headacheSeverityLabel;
    _assessmentDate = DateFormat('MMM d, yyyy').format(DateTime.now());
  }

  String? _loadError;

  // Headache fields carried from the latest combined DASS-21+headache
  // assessment (not the standalone headache log), needed to fully populate
  // _SyntheticAssessmentResult for the Detailed/Recommendations screens.
  String _headacheFrequency = '';
  int _headacheSeverity = 0;
  String _headacheDuration = '';

  Future<void> _loadLatest() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    // Fetched independently: the DASS-21 assessment history and the
    // standalone headache log are unrelated data sources, so a failure in
    // one (e.g. a transient Firestore error) must never blank out results
    // that loaded fine from the other.
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
      if (assessments.isNotEmpty) {
        final latest = assessments.first;
        // Read as num then convert — cloud_firestore_web hands whole
        // numbers back as double (JS has no int/double distinction), so a
        // bare `as int?` throws on web even though it works on Android/iOS.
        _dep = (latest['depressionScore'] as num?)?.toInt();
        _anx = (latest['anxietyScore'] as num?)?.toInt();
        _str = (latest['stressScore'] as num?)?.toInt();
        _depLevel = latest['depressionLevel'] ?? '';
        _anxLevel = latest['anxietyLevel'] ?? '';
        _strLevel = latest['stressLevel'] ?? '';
        _headacheType = latest['headacheType'] ?? '';
        _headacheSeverityLabel = latest['headacheSeverityLabel'] ?? '';
        _headacheFrequency = latest['headacheFrequency'] ?? '';
        _headacheSeverity = (latest['headacheSeverity'] as num?)?.toInt() ?? 0;
        _headacheDuration = latest['headacheDuration'] ?? '';
        try {
          final ts = latest['createdAt'] as Timestamp?;
          _assessmentDate = ts != null
              ? DateFormat('MMM d, yyyy').format(ts.toDate())
              : '';
        } catch (_) {}
      }
      if (headaches.isNotEmpty) {
        _latestHeadache = headaches.first;
      }
      _loading = false;
      // Only show the error state if BOTH sources failed and neither has
      // anything to display — a single failed source with the other still
      // showing data is a partial success, not an error.
      _loadError = (assessments.isEmpty && headaches.isEmpty)
          ? (assessmentError ?? headacheError)
          : null;
    });
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'Normal':           return const Color(0xFFD8F5E1);
      case 'Mild':             return const Color(0xFFE8F6D0);
      case 'Moderate':         return const Color(0xFFFFE79A);
      case 'Severe':           return const Color(0xFFFFD0CF);
      case 'Extremely Severe': return const Color(0xFFFFB3B0);
      default:                 return const Color(0xFFF3F3F3);
    }
  }

  Color _levelTextColor(String level) {
    switch (level) {
      case 'Normal':           return Colors.green.shade700;
      case 'Mild':             return Colors.teal.shade700;
      case 'Moderate':         return Colors.orange.shade800;
      case 'Severe':           return Colors.red.shade700;
      case 'Extremely Severe': return Colors.purple.shade700;
      default:                 return Colors.grey.shade700;
    }
  }

  AssessmentResult? _buildResult() {
    if (_originalResult != null) return _originalResult;
    if (_dep == null) return null;
    return _SyntheticAssessmentResult(
      depressionScore: _dep!,
      anxietyScore: _anx!,
      stressScore: _str!,
      depressionLevel: _depLevel,
      anxietyLevel: _anxLevel,
      stressLevel: _strLevel,
      headacheType: _headacheType,
      headacheSeverityLabel: _headacheSeverityLabel,
      headacheFrequency: _headacheFrequency,
      headacheSeverity: _headacheSeverity,
      headacheDuration: _headacheDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Results'),
        actions: [
          if (widget.result == null)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLatest),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildError()
              : (_dep == null && _latestHeadache == null)
                  ? _buildEmpty()
                  : _buildContent(),
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
            const Text('Could not load your results.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLatest,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No results yet.',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Complete a DASS-21 assessment or log a headache\nto see your results here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final result = _buildResult();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── DASS-21 Section ──────────────────────────────────────────
          if (_dep != null) ...[
            _sectionHeader(
              icon: Icons.psychology_outlined,
              color: Colors.deepPurple,
              title: 'DASS-21 Assessment',
              subtitle: _assessmentDate.isNotEmpty ? 'Last taken: $_assessmentDate' : null,
            ),
            const SizedBox(height: 12),
            _ScoreTile(
              title: 'Depression',
              score: '$_dep / 42',
              level: _depLevel,
              bgColor: _levelColor(_depLevel),
              textColor: _levelTextColor(_depLevel),
            ),
            const SizedBox(height: 10),
            _ScoreTile(
              title: 'Anxiety',
              score: '$_anx / 42',
              level: _anxLevel,
              bgColor: _levelColor(_anxLevel),
              textColor: _levelTextColor(_anxLevel),
            ),
            const SizedBox(height: 10),
            _ScoreTile(
              title: 'Stress',
              score: '$_str / 42',
              level: _strLevel,
              bgColor: _levelColor(_strLevel),
              textColor: _levelTextColor(_strLevel),
            ),

            // Headache from this assessment (if logged during DASS-21)
            if (_headacheType.isNotEmpty &&
                _headacheType != "I don't get headaches") ...[
              const SizedBox(height: 10),
              _ScoreTile(
                title: 'Headache (in assessment)',
                score: _headacheSeverityLabel,
                level: _headacheType,
                bgColor: const Color(0xFFFFF2E2),
                textColor: Colors.orange.shade800,
                icon: Icons.bolt,
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ResultsDetailedScreen(result: result)),
                    ),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Detailed'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              RecommendationsScreen(result: result)),
                    ),
                    icon: const Icon(Icons.lightbulb_outline,
                        color: Colors.white),
                    label: const Text('Recommendations',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple),
                  ),
                ),
              ],
            ),
          ],

          // ── Standalone Headache Section ──────────────────────────────
          if (_latestHeadache != null) ...[
            const SizedBox(height: 28),
            _sectionHeader(
              icon: Icons.bolt,
              color: Colors.orange,
              title: 'Latest Headache Log',
              subtitle: _fmtTs(_latestHeadache!['createdAt']),
            ),
            const SizedBox(height: 12),
            _HeadacheDetailCard(data: _latestHeadache!),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color)),
            if (subtitle != null)
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  String _fmtTs(dynamic ts) {
    if (ts == null) return '';
    try {
      return 'Logged: ${DateFormat('MMM d, yyyy  h:mm a').format((ts as Timestamp).toDate())}';
    } catch (_) {
      return '';
    }
  }
}

// ─── DASS-21 Score Tile ──────────────────────────────────────────────────────

class _ScoreTile extends StatelessWidget {
  final String title;
  final String score;
  final String level;
  final Color bgColor;
  final Color textColor;
  final IconData icon;

  const _ScoreTile({
    required this.title,
    required this.score,
    required this.level,
    required this.bgColor,
    required this.textColor,
    this.icon = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(level,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor)),
              Text(score,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Headache Detail Card ─────────────────────────────────────────────────────

class _HeadacheDetailCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HeadacheDetailCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final severity = (data['severity'] as num?)?.toInt() ?? 0;
    Color sColor;
    String sLabel;
    if (severity <= 3) { sColor = Colors.green; sLabel = 'Mild'; }
    else if (severity <= 6) { sColor = Colors.orange; sLabel = 'Moderate'; }
    else { sColor = Colors.red; sLabel = 'Severe'; }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          _Row(Icons.category_outlined, 'Type', data['type'] ?? '-', Colors.deepPurple),
          const Divider(height: 18),
          _Row(Icons.speed_outlined, 'Severity', '$severity / 10  ($sLabel)', sColor),
          const Divider(height: 18),
          _Row(Icons.timelapse_outlined, 'Duration', data['duration'] ?? '-', Colors.teal),
          const Divider(height: 18),
          _Row(Icons.repeat_outlined, 'Frequency', data['frequency'] ?? '-', Colors.blue),
          if ((data['notes'] ?? '').toString().isNotEmpty) ...[
            const Divider(height: 18),
            _Row(Icons.notes_outlined, 'Notes', data['notes'], Colors.grey),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Row(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// An AssessmentResult built from pre-computed scores (loaded from Firestore)
/// rather than raw dass21Answers.
class _SyntheticAssessmentResult extends AssessmentResult {
  final int _depScore;
  final int _anxScore;
  final int _strScore;
  final String _depLevel;
  final String _anxLevel;
  final String _strLevel;
  final String _headacheSevLabel;

  _SyntheticAssessmentResult({
    required int depressionScore,
    required int anxietyScore,
    required int stressScore,
    required String depressionLevel,
    required String anxietyLevel,
    required String stressLevel,
    required super.headacheType,
    required String headacheSeverityLabel,
    super.headacheFrequency = '',
    super.headacheSeverity = 0,
    super.headacheDuration = '',
  })  : _depScore = depressionScore,
        _anxScore = anxietyScore,
        _strScore = stressScore,
        _depLevel = depressionLevel,
        _anxLevel = anxietyLevel,
        _strLevel = stressLevel,
        _headacheSevLabel = headacheSeverityLabel,
        super(dass21Answers: List.filled(21, 0));

  @override
  int get depressionScore => _depScore;
  @override
  int get anxietyScore => _anxScore;
  @override
  int get stressScore => _strScore;
  @override
  String get depressionLevel => _depLevel;
  @override
  String get anxietyLevel => _anxLevel;
  @override
  String get stressLevel => _strLevel;
  @override
  String get headacheSeverityLabel => _headacheSevLabel;
}
