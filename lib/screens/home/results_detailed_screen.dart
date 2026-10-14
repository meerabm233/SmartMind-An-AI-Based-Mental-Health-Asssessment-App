import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/assessment_result.dart';

class ResultsDetailedScreen extends StatelessWidget {
  final AssessmentResult? result;

  const ResultsDetailedScreen({super.key, this.result});

  @override
  Widget build(BuildContext context) {
    final dep = result?.depressionScore.toDouble() ?? 21;
    final anx = result?.anxietyScore.toDouble() ?? 28;
    final str = result?.stressScore.toDouble() ?? 20;
    final depLabel = result?.depressionLevel ?? 'Moderate';
    final anxLabel = result?.anxietyLevel ?? 'Severe';
    final strLabel = result?.stressLevel ?? 'Moderate';

    return Scaffold(
      appBar: AppBar(title: const Text('Results Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DASS-21 Scores',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        reservedSize: 30,
                        getTitlesWidget: (v, _) =>
                            Text('${v.toInt()}', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final labels = ['Dep\n$depLabel', 'Anx\n$anxLabel', 'Str\n$strLabel'];
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[index],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  maxY: 42,
                  gridData: const FlGridData(show: true),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: dep,
                          color: const Color(0xFFF4C542),
                          width: 32,
                          borderRadius: BorderRadius.circular(6),
                          rodStackItems: [
                            BarChartRodStackItem(0, dep, const Color(0xFFF4C542)),
                          ],
                        )
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: anx,
                          color: const Color(0xFFE56A6A),
                          width: 32,
                          borderRadius: BorderRadius.circular(6),
                        )
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: str,
                          color: const Color(0xFF4EA8DE),
                          width: 32,
                          borderRadius: BorderRadius.circular(6),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Depression Level Guide',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const _GuideRow(range: '0-9', level: 'Normal'),
            const _GuideRow(range: '10-13', level: 'Mild'),
            const _GuideRow(range: '14-20', level: 'Moderate'),
            const _GuideRow(range: '21-27', level: 'Severe'),
            const _GuideRow(range: '28+', level: 'Extremely Severe'),
            const SizedBox(height: 20),
            const Text('Anxiety Level Guide',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const _GuideRow(range: '0-7', level: 'Normal'),
            const _GuideRow(range: '8-9', level: 'Mild'),
            const _GuideRow(range: '10-14', level: 'Moderate'),
            const _GuideRow(range: '15-19', level: 'Severe'),
            const _GuideRow(range: '20+', level: 'Extremely Severe'),
            const SizedBox(height: 20),
            const Text('Stress Level Guide',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const _GuideRow(range: '0-14', level: 'Normal'),
            const _GuideRow(range: '15-18', level: 'Mild'),
            const _GuideRow(range: '19-25', level: 'Moderate'),
            const _GuideRow(range: '26-33', level: 'Severe'),
            const _GuideRow(range: '34+', level: 'Extremely Severe'),

            // Headache details
            if (result != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 10),
              const Text('Headache Summary',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              _HeadacheDetail(label: 'Type', value: result!.headacheType),
              _HeadacheDetail(label: 'Frequency', value: result!.headacheFrequency),
              _HeadacheDetail(
                  label: 'Severity',
                  value:
                      '${result!.headacheSeverity}/10 — ${result!.headacheSeverityLabel}'),
              _HeadacheDetail(label: 'Duration', value: result!.headacheDuration),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.range, required this.level});

  final String range;
  final String level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(range, style: const TextStyle(fontSize: 13))),
          Text(level, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _HeadacheDetail extends StatelessWidget {
  const _HeadacheDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
