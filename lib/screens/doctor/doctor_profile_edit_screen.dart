import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class DoctorProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const DoctorProfileEditScreen({super.key, required this.profile});

  @override
  State<DoctorProfileEditScreen> createState() =>
      _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<DoctorProfileEditScreen> {
  late final TextEditingController _nameC;
  late final TextEditingController _specialtyC;
  late final TextEditingController _qualificationC;
  late final TextEditingController _hospitalC;
  late final TextEditingController _locationC;
  late final TextEditingController _phoneC;
  late final TextEditingController _bioC;
  late final TextEditingController _feeC;
  late bool _isOnlineAvailable;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameC = TextEditingController(text: p['name'] ?? '');
    _specialtyC = TextEditingController(text: p['specialty'] ?? '');
    _qualificationC = TextEditingController(text: p['qualification'] ?? '');
    _hospitalC = TextEditingController(text: p['hospital'] ?? '');
    _locationC = TextEditingController(text: p['location'] ?? '');
    _phoneC = TextEditingController(text: p['phone'] ?? '');
    _bioC = TextEditingController(text: p['bio'] ?? '');
    _feeC = TextEditingController(
      text: (p['consultationFee'] ?? 0).toStringAsFixed(0),
    );
    _isOnlineAvailable = p['isOnlineAvailable'] ?? true;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _specialtyC.dispose();
    _qualificationC.dispose();
    _hospitalC.dispose();
    _locationC.dispose();
    _phoneC.dispose();
    _bioC.dispose();
    _feeC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty || _specialtyC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and specialty are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.updateDoctorProfile(
        name: _nameC.text.trim(),
        specialty: _specialtyC.text.trim(),
        qualification: _qualificationC.text.trim(),
        hospital: _hospitalC.text.trim(),
        location: _locationC.text.trim(),
        phone: _phoneC.text.trim(),
        bio: _bioC.text.trim(),
        isOnlineAvailable: _isOnlineAvailable,
        consultationFee: double.tryParse(_feeC.text.trim()) ?? 0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_nameC, 'Full Name', Icons.person_outline),
            _field(_specialtyC, 'Specialty', Icons.medical_services_outlined),
            _field(_qualificationC, 'Qualification', Icons.school_outlined),
            _field(_hospitalC, 'Hospital / Clinic', Icons.local_hospital_outlined),
            _field(_locationC, 'Location', Icons.location_on_outlined),
            _field(_phoneC, 'Phone', Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            _field(_feeC, 'Consultation Fee (PKR)', Icons.payments_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 4),
            _field(_bioC, 'Bio', Icons.info_outline, maxLines: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for Online Consultation'),
              value: _isOnlineAvailable,
              onChanged: (v) => setState(() => _isOnlineAvailable = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Profile', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple.shade300),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
