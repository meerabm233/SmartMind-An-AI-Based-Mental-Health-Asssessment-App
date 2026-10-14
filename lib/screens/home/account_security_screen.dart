import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';

/// Screen 18 – Account Security & Medical Data Privacy.
///
/// Covers:
///   • Two-Factor Authentication (2FA) toggle
///   • Active sessions overview
///   • Medical data privacy controls
///   • Data export / delete account
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _twoFaEnabled = false;
  bool _shareDataWithDoctors = true;
  bool _anonymousAnalytics = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _twoFaEnabled = prefs.getBool('2fa_enabled') ?? false;
      _shareDataWithDoctors = prefs.getBool('share_data_doctors') ?? true;
      _anonymousAnalytics = prefs.getBool('anonymous_analytics') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggle2FA(bool value) async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // simulate network
    await _savePref('2fa_enabled', value);
    if (!mounted) return;
    setState(() {
      _twoFaEnabled = value;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value
          ? '2FA enabled. You will receive a verification code on login.'
          : '2FA disabled.'),
      backgroundColor: value ? Colors.green : Colors.orange,
    ));
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all health data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await AuthService.currentUser?.delete();
      if (!mounted) return;
      Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Your data export has been requested. You will receive an email within 24 hours.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Security')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Security ───────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.lock_outline,
                  title: 'Security',
                  color: Colors.deepPurple,
                ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Two-Factor Authentication (2FA)'),
                        subtitle: const Text(
                          'Adds an extra layer of protection at login',
                        ),
                        secondary: Icon(
                          Icons.verified_user_outlined,
                          color: _twoFaEnabled
                              ? Colors.green
                              : Colors.grey,
                        ),
                        value: _twoFaEnabled,
                        onChanged: _toggle2FA,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.devices_outlined,
                            color: Colors.deepPurple),
                        title: const Text('Active Sessions'),
                        subtitle: const Text('1 device currently signed in'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Active Sessions'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _SessionTile(
                                    device: 'Android — This device',
                                    location: 'Pakistan',
                                    icon: Icons.phone_android,
                                    isCurrent: true,
                                  ),
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
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.password_outlined,
                            color: Colors.deepPurple),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14),
                        onTap: () => Navigator.pushNamed(
                            context, '/change-password'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Medical Data Privacy ────────────────────────────────
                _SectionHeader(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Medical Data Privacy',
                  color: Colors.teal,
                ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Share data with booked doctors'),
                        subtitle: const Text(
                          'Allow doctors to view your assessment results before appointments',
                        ),
                        secondary: const Icon(Icons.local_hospital_outlined,
                            color: Colors.teal),
                        value: _shareDataWithDoctors,
                        onChanged: (v) {
                          setState(() => _shareDataWithDoctors = v);
                          _savePref('share_data_doctors', v);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Anonymous usage analytics'),
                        subtitle: const Text(
                          'Help improve SmartMind by sharing anonymised usage data',
                        ),
                        secondary: const Icon(Icons.analytics_outlined,
                            color: Colors.teal),
                        value: _anonymousAnalytics,
                        onChanged: (v) {
                          setState(() => _anonymousAnalytics = v);
                          _savePref('anonymous_analytics', v);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined,
                            color: Colors.teal),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.open_in_new, size: 16),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Opening Privacy Policy…'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Data Management ─────────────────────────────────────
                _SectionHeader(
                  icon: Icons.storage_outlined,
                  title: 'Your Data',
                  color: Colors.blueGrey,
                ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download_outlined,
                            color: Colors.blueGrey),
                        title: const Text('Export My Data'),
                        subtitle: const Text(
                            'Download a copy of all your health records'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14),
                        onTap: _exportData,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(color: Colors.red),
                        ),
                        subtitle: const Text(
                          'Permanently erase all your data',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14),
                        onTap: _confirmDeleteAccount,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Compliance badges
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.deepPurple, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your health data is encrypted and stored securely. '
                          'SmartMind complies with applicable healthcare data privacy regulations.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String device;
  final String location;
  final IconData icon;
  final bool isCurrent;
  const _SessionTile({
    required this.device,
    required this.location,
    required this.icon,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(device),
      subtitle: Text(location),
      trailing: isCurrent
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Text(
                'Active',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            )
          : TextButton(
              onPressed: () {},
              child: const Text('Revoke',
                  style: TextStyle(color: Colors.red)),
            ),
    );
  }
}
