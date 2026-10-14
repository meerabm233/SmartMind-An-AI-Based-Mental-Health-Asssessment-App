import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import 'account_security_screen.dart';
import 'change_password_screen.dart';
import 'notification_settings_screen.dart';
import 'personal_info_screen.dart';
import 'privacy_policy_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  String _photoUrl = '';
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final data = await FirestoreService.getUserProfile();
    if (!mounted) return;
    setState(() {
      _name = data['name']!.isNotEmpty ? data['name']! : 'User';
      _email = data['email']!.isNotEmpty ? data['email']! : '';
      _photoUrl = data['photoUrl'] ?? '';
      if (_photoUrl.startsWith('data:')) {
        final base64Str = _photoUrl.split(',').last;
        _imageBytes = base64Decode(base64Str);
      } else {
        _imageBytes = null;
      }
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Help & Support',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Frequently Asked Questions',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                    fontSize: 15)),
            const SizedBox(height: 12),
            _faqTile('What is the DASS-21 assessment?',
                'The DASS-21 is a validated screening tool that measures Depression, Anxiety, and Stress. It consists of 21 questions and provides severity levels for each area.'),
            _faqTile('How often should I take the assessment?',
                'We recommend taking the DASS-21 every 2-4 weeks to track your mental health progress over time.'),
            _faqTile('Is my data private?',
                'Yes. Your data is stored securely in Firebase and is only accessible to you. We do not share your personal information with third parties.'),
            _faqTile('How does the headache tracker work?',
                'The headache tracker lets you log headache type, frequency, severity, and duration. Over time, it helps identify patterns and triggers.'),
            _faqTile('Can I book a real appointment?',
                'The doctor profiles and appointments feature allows you to connect with mental health professionals. Consult the listed doctors for availability.'),
            const SizedBox(height: 20),
            const Text('Contact Us',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                    fontSize: 15)),
            const SizedBox(height: 12),
            ListTile(
              leading:
                  const Icon(Icons.email_outlined, color: Colors.deepPurple),
              title: const Text('Email Support'),
              subtitle: const Text('smartmind.support@gmail.com'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFEAE7FF),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.bug_report_outlined, color: Colors.deepPurple),
              title: const Text('Report a Bug'),
              subtitle: const Text('Help us improve SmartMind'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFEAE7FF),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Please email us at smartmind.support@gmail.com with bug details.'),
                    backgroundColor: Colors.deepPurple,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _faqTile(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title:
            Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade200],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundImage: _imageBytes != null
                        ? MemoryImage(_imageBytes!) as ImageProvider
                        : (_photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(_photoUrl)
                            : null),
                    backgroundColor: Colors.deepPurple.shade100,
                    child: (_imageBytes == null && _photoUrl.isEmpty)
                      ? const Icon(Icons.person, size: 42, color: Colors.white)
                      : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  Text(_email, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Menu tiles
            _Tile(
              icon: Icons.person_outline,
              title: 'Personal Information',
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PersonalInfoScreen()));
                _loadUser();
              },
            ),
            _Tile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
            _Tile(
              icon: Icons.verified_user_outlined,
              title: 'Account Security',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AccountSecurityScreen())),
            ),
            _Tile(
              icon: Icons.notifications_outlined,
              title: 'Notification Settings',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen())),
            ),
            _Tile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            _Tile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () => _showHelpSupport(context),
            ),
            _Tile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(height: 16),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Logout',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
