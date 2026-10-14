import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../doctor/doctors_list_screen.dart';
import '../doctor/my_appointments_screen.dart';
import '../headache/headache_module_screen.dart';
import 'assessment_intro_screen.dart';
import 'chatbot_screen.dart';
import 'notification_settings_screen.dart';
import 'results_overview_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  static const _moods = [
    {'emoji': '😁', 'label': 'Great'},
    {'emoji': '🙂', 'label': 'Good'},
    {'emoji': '😐', 'label': 'Okay'},
    {'emoji': '😔', 'label': 'Low'},
    {'emoji': '😢', 'label': 'Bad'},
  ];

  int? _selectedMood;

  @override
  void initState() {
    super.initState();
    _loadMood();
  }

  Future<void> _loadMood() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final saved = prefs.getString('daily_mood_date');
    if (saved == today) {
      final idx = prefs.getInt('daily_mood_index');
      if (mounted) setState(() => _selectedMood = idx);
    }
  }

  Future<void> _saveMood(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('daily_mood_date', today);
    await prefs.setInt('daily_mood_index', index);
    setState(() => _selectedMood = index);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Mood logged: ${_moods[index]['emoji']} ${_moods[index]['label']}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hello 👋',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'How are you feeling today?',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_none),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Daily Mood Tracker ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade50,
                    Colors.deepPurple.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Daily Mood Check-in',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const Spacer(),
                      if (_selectedMood != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Logged ✓',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_moods.length, (i) {
                      final selected = _selectedMood == i;
                      return GestureDetector(
                        onTap: () => _saveMood(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.deepPurple
                                : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color:
                                            Colors.deepPurple.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1)
                                  ]
                                : [],
                          ),
                          child: Column(
                            children: [
                              Text(
                                _moods[i]['emoji']!,
                                style: const TextStyle(fontSize: 26),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _moods[i]['label']!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _ActionCard(
              title: 'Start Assessment',
              subtitle: 'Take DASS-21 test',
              icon: Icons.psychology_alt_outlined,
              color: const Color(0xFFEAE7FF),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AssessmentIntroScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _ActionCard(
              title: 'Headache Tracker',
              subtitle: 'Log and monitor headaches',
              icon: Icons.healing_outlined,
              color: const Color(0xFFFFF2E2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HeadacheModuleScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _ActionCard(
              title: 'Doctor Profiles',
              subtitle: 'Find specialists and book',
              icon: Icons.local_hospital_outlined,
              color: const Color(0xFFE8F6EE),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorsListScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _ActionCard(
              title: 'My Appointments',
              subtitle: 'View your booked appointments',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFFE8EAF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyAppointmentsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _ActionCard(
              title: 'View Results',
              subtitle: 'See your progress',
              icon: Icons.description_outlined,
              color: const Color(0xFFE8F6EE),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ResultsOverviewScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _ActionCard(
              title: 'Chat with AI',
              subtitle: 'Talk and get support',
              icon: Icons.chat_bubble_outline,
              color: const Color(0xFFFFF2E2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(icon, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
