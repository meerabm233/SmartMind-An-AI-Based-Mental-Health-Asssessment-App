import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _dailyReminder = true;
  bool _assessmentReminder = true;
  bool _moodCheckIn = false;
  bool _weeklyReport = true;
  bool _tips = true;
  bool _appUpdates = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _assessmentReminderTime = const TimeOfDay(hour: 10, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dailyReminder = prefs.getBool('notif_daily_reminder') ?? true;
      _assessmentReminder = prefs.getBool('notif_assessment_reminder') ?? true;
      _moodCheckIn = prefs.getBool('notif_mood_checkin') ?? false;
      _weeklyReport = prefs.getBool('notif_weekly_report') ?? true;
      _tips = prefs.getBool('notif_tips') ?? true;
      _appUpdates = prefs.getBool('notif_app_updates') ?? false;
      _reminderTime = TimeOfDay(
        hour: prefs.getInt('notif_reminder_hour') ?? 9,
        minute: prefs.getInt('notif_reminder_minute') ?? 0,
      );
      _assessmentReminderTime = TimeOfDay(
        hour: prefs.getInt('notif_assessment_hour') ?? 10,
        minute: prefs.getInt('notif_assessment_minute') ?? 0,
      );
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_daily_reminder', _dailyReminder);
    await prefs.setBool('notif_assessment_reminder', _assessmentReminder);
    await prefs.setBool('notif_mood_checkin', _moodCheckIn);
    await prefs.setBool('notif_weekly_report', _weeklyReport);
    await prefs.setBool('notif_tips', _tips);
    await prefs.setBool('notif_app_updates', _appUpdates);
    await prefs.setInt('notif_reminder_hour', _reminderTime.hour);
    await prefs.setInt('notif_reminder_minute', _reminderTime.minute);
    await prefs.setInt('notif_assessment_hour', _assessmentReminderTime.hour);
    await prefs.setInt('notif_assessment_minute', _assessmentReminderTime.minute);

    final needsPermission = _dailyReminder || _assessmentReminder;
    final granted = needsPermission
        ? await NotificationService.requestPermission()
        : true;

    if (_dailyReminder && granted) {
      await NotificationService.scheduleDaily(
        id: ReminderIds.dailyReminder,
        title: 'Daily Check-in',
        body: "It's time for your daily mental health check-in.",
        time: _reminderTime,
      );
    } else {
      await NotificationService.cancel(ReminderIds.dailyReminder);
    }

    if (_assessmentReminder && granted) {
      await NotificationService.scheduleDaily(
        id: ReminderIds.assessmentReminder,
        title: 'Assessment Reminder',
        body: 'Take a moment to complete your DASS-21 assessment.',
        time: _assessmentReminderTime,
      );
    } else {
      await NotificationService.cancel(ReminderIds.assessmentReminder);
    }

    if (!mounted) return;
    if (needsPermission && !granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Settings saved, but notification permission was denied — '
              'reminders won\'t appear until it\'s allowed in system settings.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification settings saved!'),
        backgroundColor: Colors.deepPurple,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _pickTime({bool isAssessment = false}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isAssessment ? _assessmentReminderTime : _reminderTime,
    );
    if (picked != null) {
      setState(() {
        if (isAssessment) {
          _assessmentReminderTime = picked;
        } else {
          _reminderTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          _SectionHeader(title: 'Reminders'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Daily Reminder'),
            subtitle: const Text('Get a daily check-in reminder'),
            value: _dailyReminder,
            onChanged: (v) => setState(() => _dailyReminder = v),
          ),
          if (_dailyReminder)
            ListTile(
              leading: const Icon(Icons.access_time_outlined),
              title: const Text('Reminder Time'),
              subtitle: Text(_reminderTime.format(context)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _pickTime(),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.assignment_outlined),
            title: const Text('Assessment Reminder'),
            subtitle: const Text('Remind me to complete assessments'),
            value: _assessmentReminder,
            onChanged: (v) => setState(() => _assessmentReminder = v),
          ),
          if (_assessmentReminder)
            ListTile(
              leading: const Icon(Icons.access_time_outlined),
              title: const Text('Assessment Reminder Time'),
              subtitle: Text(_assessmentReminderTime.format(context)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _pickTime(isAssessment: true),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.mood_outlined),
            title: const Text('Mood Check-in'),
            subtitle: const Text('Quick mood tracking prompts'),
            value: _moodCheckIn,
            onChanged: (v) => setState(() => _moodCheckIn = v),
          ),
          const Divider(),
          _SectionHeader(title: 'Reports & Tips'),
          SwitchListTile(
            secondary: const Icon(Icons.bar_chart_outlined),
            title: const Text('Weekly Progress Report'),
            subtitle: const Text('Summary of your mental health week'),
            value: _weeklyReport,
            onChanged: (v) => setState(() => _weeklyReport = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb_outline),
            title: const Text('Wellness Tips'),
            subtitle: const Text('Daily mental health tips and articles'),
            value: _tips,
            onChanged: (v) => setState(() => _tips = v),
          ),
          const Divider(),
          _SectionHeader(title: 'General'),
          SwitchListTile(
            secondary: const Icon(Icons.system_update_outlined),
            title: const Text('App Updates'),
            subtitle: const Text('New features and important changes'),
            value: _appUpdates,
            onChanged: (v) => setState(() => _appUpdates = v),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  const Text('Save Settings', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
