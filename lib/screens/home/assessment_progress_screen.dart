import 'dart:async';

import 'package:flutter/material.dart';

import 'results_overview_screen.dart';

class AssessmentProgressScreen extends StatefulWidget {
  const AssessmentProgressScreen({super.key});

  @override
  State<AssessmentProgressScreen> createState() => _AssessmentProgressScreenState();
}

class _AssessmentProgressScreenState extends State<AssessmentProgressScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ResultsOverviewScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Progress')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '15 of 21 completed',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(value: 15 / 21, minHeight: 10),
              ),
              const SizedBox(height: 28),
              CircleAvatar(
                radius: 56,
                backgroundColor: Colors.deepPurple.shade50,
                child: Icon(
                  Icons.psychology_alt_outlined,
                  size: 54,
                  color: Colors.deepPurple.shade300,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You\'re doing great!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Please answer all questions honestly for accurate results.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              )
            ],
          ),
        ),
      ),
    );
  }
}
