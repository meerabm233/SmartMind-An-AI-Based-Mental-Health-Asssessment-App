import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool reminders = true;
  bool darkMode = false;
  bool sound = true;
  String _selectedLanguage = 'English';

  static const _languages = [
    'English',
    'Urdu',
    'Arabic',
    'Hindi',
    'Spanish',
    'French',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      reminders = prefs.getBool('reminders') ?? true;
      darkMode = themeModeNotifier.value == ThemeMode.dark;
      sound = prefs.getBool('sound') ?? true;
      _selectedLanguage = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    if (mounted) setState(() => darkMode = value);
  }

  Future<void> _toggleReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders', value);
    if (mounted) setState(() => reminders = value);
  }

  Future<void> _toggleSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound', value);
    if (mounted) setState(() => sound = value);
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: _languages
            .map((lang) => SimpleDialogOption(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('language', lang);
                    if (!mounted) return;
                    setState(() => _selectedLanguage = lang);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Language set to $lang'),
                        backgroundColor: Colors.deepPurple,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        _selectedLanguage == lang
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _selectedLanguage == lang
                            ? Colors.deepPurple
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(lang),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.psychology, color: Colors.deepPurple, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('About SmartMind'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SmartMind is an AI-based mental health assessment and support application.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text('Features:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ...[
              'DASS-21 Depression, Anxiety & Stress Assessment',
              'Headache Type Detection & Tracking',
              'AI-Powered Mental Health Chat Support',
              'Doctor Appointment Booking',
              'Progress Tracking & History',
              'Personalized Recommendations',
            ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('  • ',
                          style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Text(f, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Text('Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Developed for FYP Project',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Daily Assessment Reminder'),
            subtitle: const Text('Reminders'),
            value: reminders,
            onChanged: _toggleReminders,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: darkMode,
            onChanged: _toggleDarkMode,
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Language'),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _showLanguageDialog,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Sound'),
            value: sound,
            onChanged: _toggleSound,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About SmartMind'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _showAboutDialog,
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text('Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }
}
