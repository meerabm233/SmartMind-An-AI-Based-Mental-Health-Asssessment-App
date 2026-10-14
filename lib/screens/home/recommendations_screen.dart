import 'package:flutter/material.dart';

import '../../models/assessment_result.dart';

class RecommendationsScreen extends StatelessWidget {
  final AssessmentResult? result;

  const RecommendationsScreen({super.key, this.result});

  // ---- Tailored advice per level ----
  static List<String> _depressionTips(String level) {
    switch (level) {
      case 'Normal':
        return ['Keep up your healthy habits!', 'Stay socially connected'];
      case 'Mild':
        return [
          'Engage in activities you enjoy',
          'Spend time outdoors',
          'Maintain a consistent sleep schedule',
        ];
      case 'Moderate':
        return [
          'Stay connected with friends & family',
          'Do activities you enjoy daily',
          'Consider talking to a counsellor',
          'Practice gratitude journaling',
        ];
      case 'Severe':
      default:
        return [
          'Seek professional psychological support urgently',
          'Reach out to a trusted person today',
          'Avoid isolation — stay with others',
          'Contact a mental health helpline if needed',
        ];
    }
  }

  static List<String> _anxietyTips(String level) {
    switch (level) {
      case 'Normal':
        return ['Continue stress management practices', 'Maintain a balanced routine'];
      case 'Mild':
        return [
          'Practice 4-7-8 breathing exercises',
          'Limit caffeine intake',
          'Try a 10-minute walk when anxious',
        ];
      case 'Moderate':
        return [
          'Practice deep breathing daily',
          'Try meditation or mindfulness',
          'Reduce caffeine and screen time',
          'Consider CBT or therapy',
        ];
      case 'Severe':
      default:
        return [
          'Consult a mental health professional',
          'Practice grounding techniques (5-4-3-2-1)',
          'Reduce caffeine completely',
          'Medication evaluation may be warranted',
        ];
    }
  }

  static List<String> _stressTips(String level) {
    switch (level) {
      case 'Normal':
        return ['Keep balancing work and rest', 'Celebrate small wins'];
      case 'Mild':
        return [
          'Take regular short breaks',
          'Try progressive muscle relaxation',
          'Plan your week in advance',
        ];
      case 'Moderate':
        return [
          'Take short breaks every 90 minutes',
          'Exercise at least 3 times a week',
          'Maintain a healthy routine',
          'Delegate tasks when possible',
        ];
      case 'Severe':
      default:
        return [
          'Reduce workload immediately if possible',
          'Seek stress management counselling',
          'Prioritise sleep (7-9 hours)',
          'Avoid overcommitting to new tasks',
        ];
    }
  }

  static List<String> _headacheTips(String type, String severity) {
    final tips = <String>[];
    switch (type) {
      case 'Tension':
        tips.addAll([
          'Stretch your neck and shoulders regularly',
          'Check your posture and ergonomics',
          'Stay hydrated throughout the day',
        ]);
      case 'Migraine':
        tips.addAll([
          'Keep a migraine diary to identify triggers',
          'Avoid bright screens during attacks',
          'Consult a neurologist if migraines are frequent',
        ]);
      case 'Cluster':
        tips.addAll([
          'Avoid alcohol during cluster periods',
          'Oxygen therapy may help — consult a doctor',
          'Track attack patterns to predict onset',
        ]);
      default:
        tips.add('Speak to your doctor about your headache type');
    }
    if (severity == 'Severe') {
      tips.add('Your headache severity is high — please see a physician');
    }
    return tips;
  }

  Color _blockColor(String level) {
    switch (level) {
      case 'Normal':
        return const Color(0xFFD8F5E1);
      case 'Mild':
        return const Color(0xFFECF5D0);
      case 'Moderate':
        return const Color(0xFFFFF0CF);
      case 'Severe':
        return const Color(0xFFFFDDE0);
      default:
        return const Color(0xFFFFB3B0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final depLevel = result?.depressionLevel ?? 'Moderate';
    final anxLevel = result?.anxietyLevel ?? 'Severe';
    final strLevel = result?.stressLevel ?? 'Moderate';
    final headType = result?.headacheType ?? 'Tension';
    final headSev = result?.headacheSeverityLabel ?? 'Moderate';
    final showHeadache =
        result == null || result!.headacheType != "I don't get headaches";

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Based on your results, here are personalised recommendations.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            _RecommendationBlock(
              title: 'Depression ($depLevel)',
              items: _depressionTips(depLevel),
              color: _blockColor(depLevel),
            ),
            const SizedBox(height: 12),
            _RecommendationBlock(
              title: 'Anxiety ($anxLevel)',
              items: _anxietyTips(anxLevel),
              color: _blockColor(anxLevel),
            ),
            const SizedBox(height: 12),
            _RecommendationBlock(
              title: 'Stress ($strLevel)',
              items: _stressTips(strLevel),
              color: _blockColor(strLevel),
            ),
            if (showHeadache) ...[
              const SizedBox(height: 12),
              _RecommendationBlock(
                title: 'Headache — $headType ($headSev)',
                items: _headacheTips(headType, headSev),
                color: Colors.orange.shade50,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Chat with AI for more'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _RecommendationBlock extends StatelessWidget {
  const _RecommendationBlock({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('• $item'),
              )),
        ],
      ),
    );
  }
}
