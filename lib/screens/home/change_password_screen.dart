import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  bool get _isSocialUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any(
        (p) => p.providerId == 'google.com' || p.providerId == 'facebook.com');
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMsg('No user logged in.', isError: true);
        return;
      }

      // Re-authenticate with current password first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Now update to new password
      await user.updatePassword(_newController.text);
      if (!mounted) return;
      _showMsg('Password updated successfully!');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Current password is incorrect. Please try again.';
          break;
        case 'weak-password':
          msg = 'New password is too weak.';
          break;
        case 'requires-recent-login':
          msg =
              'Session expired. Please log out and log back in, then try again.';
          break;
        default:
          msg = e.message ?? 'Failed to update password.';
      }
      _showMsg(msg, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showMsg('Failed to update password: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendResetEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    if (email.isEmpty) {
      _showMsg('No email associated with this account.', isError: true);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showMsg('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showMsg(e.message ?? 'Could not send reset email.', isError: true);
    } catch (e) {
      if (!mounted) return;
      _showMsg('Could not send reset email: ${e.toString()}', isError: true);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.deepPurple,
    ));
  }

  String? _validateNew(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    if (v.length < 8) return 'Minimum 8 characters';
    if (!v.contains(RegExp(r'[A-Z]'))) {
      return 'Include at least one uppercase letter';
    }
    if (!v.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _isSocialUser ? _buildSocialView() : _buildEmailView(),
      ),
    );
  }

  Widget _buildSocialView() {
    final user = FirebaseAuth.instance.currentUser;
    final providers =
        user?.providerData.map((p) => p.providerId).toList() ?? [];
    final providerLabel =
        providers.contains('google.com') ? 'Google' : 'Facebook';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You are signed in with $providerLabel. Your password is managed by $providerLabel.\n\n'
                  'If you want to set a password for this SmartMind account, '
                  'we will send a password reset link to your email.',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (user?.email != null) ...[
          Text(
            'Email on file:',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            user!.email!,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 28),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sendResetEmail,
            icon: const Icon(Icons.mail_outline, color: Colors.white),
            label: const Text('Send Password Reset Email',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAE7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.deepPurple),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Password must be at least 8 characters, include one uppercase letter and one number.',
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildPasswordField(
            controller: _currentController,
            label: 'Current Password',
            show: _showCurrent,
            onToggle: () => setState(() => _showCurrent = !_showCurrent),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your current password' : null,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _newController,
            label: 'New Password',
            show: _showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
            validator: _validateNew,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _confirmController,
            label: 'Confirm New Password',
            show: _showConfirm,
            onToggle: () => setState(() => _showConfirm = !_showConfirm),
            validator: (v) =>
                v != _newController.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Update Password',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _sendResetEmail,
              child: const Text('Forgot current password? Send reset email'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(show
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
