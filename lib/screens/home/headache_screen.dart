import 'package:flutter/material.dart';

import '../../models/assessment_result.dart';
import 'results_overview_screen.dart';
import '../../services/firestore_service.dart';

/// Headache questionnaire — collected after DASS-21.
class HeadacheScreen extends StatefulWidget {
  final List<int> dass21Answers;

  const HeadacheScreen({super.key, required this.dass21Answers});

  @override
  State<HeadacheScreen> createState() => _HeadacheScreenState();
}

class _HeadacheScreenState extends State<HeadacheScreen> {
  static const _types = ['Tension', 'Migraine', 'Cluster', 'Other', 'I don\'t get headaches'];
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

  String? _selectedType;
  String? _selectedFrequency;
  String? _selectedDuration;
  int _severity = 5;
  bool _submitting = false;

  bool get _isComplete =>
      _selectedType != null && _selectedFrequency != null && _selectedDuration != null;

  void _showIncompleteWarning() {
    final missing = [
      if (_selectedType == null) 'headache type',
      if (_selectedFrequency == null) 'frequency',
      if (_selectedDuration == null) 'duration',
    ].join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please select: $missing')),
    );
  }

    Future<void> _submit() async {
    // Guards against duplicate saves if the button is tapped more than
    // once before navigation happens (e.g. a slow connection).
    if (_submitting) return;
    setState(() => _submitting = true);

    final result = AssessmentResult(
      dass21Answers: widget.dass21Answers,
      headacheType: _selectedType!,
      headacheFrequency: _selectedFrequency!,
      headacheSeverity: _severity,
      headacheDuration: _selectedDuration!,
    );
      // Save to Firestore
      try {
        await FirestoreService.saveAssessmentResult(result);
      } catch (e) {
        debugPrint('Failed to save assessment result: $e');
      }
      if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultsOverviewScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Headache Assessment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.headphones_outlined,
                      size: 40, color: Colors.orange.shade400),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Headache Assessment',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          'Helps us understand your headache patterns alongside your DASS-21 results.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Q1 – Type
            _SectionTitle(
              number: '1',
              title: 'What type of headache do you usually experience?',
            ),
            const SizedBox(height: 10),
            ..._types.map(
              (t) => _OptionTile(
                label: t,
                subtitle: _typeDescription(t),
                selected: _selectedType == t,
                onTap: () => setState(() => _selectedType = t),
              ),
            ),

            const SizedBox(height: 28),

            // Q2 – Frequency
            _SectionTitle(
              number: '2',
              title: 'How often do you get headaches?',
            ),
            const SizedBox(height: 10),
            ..._frequencies.map(
              (f) => _OptionTile(
                label: f,
                selected: _selectedFrequency == f,
                onTap: () => setState(() => _selectedFrequency = f),
              ),
            ),

            const SizedBox(height: 28),

            // Q3 – Severity slider
            _SectionTitle(
              number: '3',
              title: 'How severe is your headache pain? (1 = mild, 10 = unbearable)',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _severityColor(_severity).withAlpha(30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _severityColor(_severity).withAlpha(100)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pain Level: $_severity / 10',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _severityColor(_severity),
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _severityColor(_severity).withAlpha(46),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _severityLabel(_severity),
                          style: TextStyle(
                            color: _severityColor(_severity),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _severity.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: _severityColor(_severity),
                    onChanged: (v) => setState(() => _severity = v.toInt()),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1\nMild', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                      Text('5\nModerate', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                      Text('10\nSevere', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Q4 – Duration
            _SectionTitle(
              number: '4',
              title: 'How long do your headaches typically last?',
            ),
            const SizedBox(height: 10),
            ..._durations.map(
              (d) => _OptionTile(
                label: d,
                selected: _selectedDuration == d,
                onTap: () => setState(() => _selectedDuration = d),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : (_isComplete ? _submit : _showIncompleteWarning),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('View My Results', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _typeDescription(String type) {
    switch (type) {
      case 'Tension':
        return 'Dull, aching pressure — both sides of head';
      case 'Migraine':
        return 'Throbbing pain, often with nausea or light sensitivity';
      case 'Cluster':
        return 'Intense burning pain around one eye';
      case 'Other':
        return 'Another type not listed above';
      case "I don't get headaches":
        return 'No headaches';
      default:
        return '';
    }
  }

  Color _severityColor(int v) {
    if (v <= 3) return Colors.green;
    if (v <= 6) return Colors.orange;
    return Colors.red;
  }

  String _severityLabel(int v) {
    if (v <= 3) return 'Mild';
    if (v <= 6) return 'Moderate';
    return 'Severe';
  }
}

class _SectionTitle extends StatelessWidget {
  final String number;
  final String title;

  const _SectionTitle({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: Colors.deepPurple,
          child: Text(number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? Colors.deepPurple.shade50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Colors.deepPurple : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? Colors.deepPurple : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(subtitle!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
