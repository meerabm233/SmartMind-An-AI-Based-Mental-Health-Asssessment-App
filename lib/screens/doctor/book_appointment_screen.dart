import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/doctor_model.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_service.dart';
import 'safepay_checkout_screen.dart';

class BookAppointmentScreen extends StatefulWidget {
  final DoctorModel doctor;
  const BookAppointmentScreen({super.key, required this.doctor});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

// ── Payment methods ──────────────────────────────────────────────────────────
enum _PaymentMethod { jazzcash, easypaisa, safepay }

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime? _selectedDate;
  String? _selectedTime;
  String _mode = 'Online';
  final _notesController = TextEditingController();
  bool _booking = false;

  // Live set of already-booked times for the selected date, subtracted from
  // doctor.availableTimes before rendering — streamed rather than fetched
  // once, so a slot someone else just took disappears without reopening
  // this screen.
  Set<String> _takenTimes = {};
  StreamSubscription<Set<String>>? _takenSub;

  // Payment
  _PaymentMethod _paymentMethod = _PaymentMethod.safepay;
  final _mobileNumberController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    _mobileNumberController.dispose();
    _takenSub?.cancel();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _takenTimes = {};
    });
    _takenSub?.cancel();
    _takenSub = FirestoreService.watchTakenSlotTimes(widget.doctor.id, picked)
        .listen((taken) {
      if (!mounted) return;
      setState(() {
        _takenTimes = taken;
        // The previously chosen time may no longer be valid (now taken, or
        // in the past for today).
        if (_selectedTime != null &&
            (taken.contains(_selectedTime) || _isTimeInPast(_selectedTime!))) {
          _selectedTime = null;
        }
      });
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// True if [time] (format "HH:mm") has already passed today. Only
  /// meaningful when the selected date is today — future dates never have
  /// a "past" time.
  bool _isTimeInPast(String time) {
    if (_selectedDate == null || !_isSameDay(_selectedDate!, DateTime.now())) {
      return false;
    }
    final parts = time.split(':');
    final slot = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, int.parse(parts[0]), int.parse(parts[1]));
    return slot.isBefore(DateTime.now());
  }

  Future<void> _book() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time.')),
      );
      return;
    }
    if (_isTimeInPast(_selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('That time has already passed. Please pick another slot.')),
      );
      setState(() => _selectedTime = null);
      return;
    }

    // Validate payment details before proceeding. Safepay collects its own
    // payment details on its hosted checkout page, so only the mock
    // JazzCash/EasyPaisa tabs need local validation.
    if (_paymentMethod != _PaymentMethod.safepay &&
        _mobileNumberController.text.trim().length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 11-digit mobile number.')),
      );
      return;
    }

    final timeParts = _selectedTime!.split(':');
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    if (_paymentMethod == _PaymentMethod.safepay) {
      await _payWithSafepay(dt);
      return;
    }

    setState(() => _booking = true);
    try {
      final paymentLabel = switch (_paymentMethod) {
        _PaymentMethod.jazzcash => 'JazzCash',
        _PaymentMethod.easypaisa => 'EasyPaisa',
        _PaymentMethod.safepay => 'Safepay',
      };

      await FirestoreService.bookAppointment(
        doctorId: widget.doctor.id,
        doctorName: widget.doctor.name,
        specialty: widget.doctor.specialty,
        dateTime: dt,
        mode: _mode,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      _showSuccess(paymentLabel);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _payWithSafepay(DateTime dateTime) async {
    setState(() => _booking = true);
    try {
      final init = await PaymentService.initiateSafepayPayment(
        doctorId: widget.doctor.id,
        dateTime: dateTime,
        mode: _mode,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      final result = await Navigator.push<SafepayCheckoutResult>(
        context,
        MaterialPageRoute(
          builder: (_) => SafepayCheckoutScreen(
            orderRefNum: init.orderRefNum,
            checkoutUrl: init.checkoutUrl,
          ),
        ),
      );

      if (!mounted) return;
      if (result?.outcome == SafepayCheckoutOutcome.paid) {
        _showSuccess('Safepay');
      } else if (result?.outcome == SafepayCheckoutOutcome.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment failed. Please try again.'),
              backgroundColor: Colors.red),
        );
      } else {
        // Cancelled, or the screen was popped with no result: user backed
        // out of checkout. Release the held slot lock so it doesn't stay
        // permanently unbookable.
        await PaymentService.cancelPendingPayment(init.orderRefNum);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _showSuccess(String paymentMethod) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 14),
            const Text(
              'Appointment Booked!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Your appointment with ${widget.doctor.name} has been booked for '
              '${DateFormat('MMM d, yyyy').format(_selectedDate!)} at $_selectedTime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              'Payment via $paymentMethod',
              style: const TextStyle(
                  color: Colors.deepPurple, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to doctor detail
              Navigator.pop(context); // go back to doctors list
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple),
            child: const Text('Done',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor summary card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: doctor.photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(doctor.photoUrl,
                                fit: BoxFit.cover))
                        : Icon(Icons.person,
                            color: Colors.deepPurple.shade300, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(doctor.specialty,
                          style: TextStyle(
                              color: Colors.deepPurple.shade400,
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Select date
            _sectionLabel('Select Date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.deepPurple),
                    const SizedBox(width: 10),
                    Text(
                      _selectedDate == null
                          ? 'Tap to select date'
                          : DateFormat('EEEE, MMM d, yyyy')
                              .format(_selectedDate!),
                      style: TextStyle(
                          color: _selectedDate == null
                              ? Colors.grey
                              : Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Select time
            _sectionLabel('Select Time'),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final available = doctor.availableTimes
                  .where((t) => !_takenTimes.contains(t))
                  .toList();
              if (_selectedDate != null && available.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    'All slots for this date are booked. Please pick another date.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: available.map((t) {
                  final sel = _selectedTime == t;
                  final past = _isTimeInPast(t);
                  return ChoiceChip(
                    label: Text(t),
                    selected: sel,
                    onSelected:
                        past ? null : (_) => setState(() => _selectedTime = t),
                    selectedColor: Colors.deepPurple.shade100,
                    disabledColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                        color: past
                            ? Colors.grey.shade400
                            : (sel
                                ? Colors.deepPurple.shade800
                                : Colors.black)),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 18),

            // Mode
            _sectionLabel('Consultation Mode'),
            const SizedBox(height: 10),
            Row(
              children: [
                if (doctor.isOnlineAvailable)
                  _ModeChip(
                    label: 'Online',
                    icon: Icons.videocam_outlined,
                    selected: _mode == 'Online',
                    onTap: () => setState(() => _mode = 'Online'),
                  ),
                const SizedBox(width: 10),
                _ModeChip(
                  label: 'In-Person',
                  icon: Icons.location_on_outlined,
                  selected: _mode == 'In-Person',
                  onTap: () => setState(() => _mode = 'In-Person'),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Notes
            _sectionLabel('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any symptoms or concerns for the doctor...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 22),

            // ── Payment Gateway ───────────────────────────────────────
            _sectionLabel('Payment Method'),
            const SizedBox(height: 10),
            _PaymentGatewaySection(
              selected: _paymentMethod,
              onChanged: (m) => setState(() => _paymentMethod = m),
              mobileController: _mobileNumberController,
              consultationFee: widget.doctor.consultationFee,
            ),
            const SizedBox(height: 28),

            // Book button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _booking ? null : _book,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _booking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm Appointment',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

    Widget _sectionLabel(String text) => Text(
        text,
        style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      );
}

// ── Payment Gateway Widget ────────────────────────────────────────────────────

class _PaymentGatewaySection extends StatelessWidget {
  final _PaymentMethod selected;
  final ValueChanged<_PaymentMethod> onChanged;
  final TextEditingController mobileController;
  final double consultationFee;

  const _PaymentGatewaySection({
    required this.selected,
    required this.onChanged,
    required this.mobileController,
    required this.consultationFee,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fee summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: Colors.deepPurple),
              const SizedBox(width: 10),
              const Text('Consultation Fee:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                'PKR ${consultationFee.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.deepPurple),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Method selector tabs
        Row(
          children: [
            _MethodTab(
              label: 'JazzCash',
              color: const Color(0xFFD42D27),
              selected: selected == _PaymentMethod.jazzcash,
              onTap: () => onChanged(_PaymentMethod.jazzcash),
            ),
            const SizedBox(width: 8),
            _MethodTab(
              label: 'EasyPaisa',
              color: const Color(0xFF35A93E),
              selected: selected == _PaymentMethod.easypaisa,
              onTap: () => onChanged(_PaymentMethod.easypaisa),
            ),
            const SizedBox(width: 8),
            _MethodTab(
              label: 'Safepay',
              color: const Color(0xFF1F8A70),
              selected: selected == _PaymentMethod.safepay,
              onTap: () => onChanged(_PaymentMethod.safepay),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Dynamic form
        if (selected == _PaymentMethod.jazzcash ||
            selected == _PaymentMethod.easypaisa)
          _MobilePaymentForm(
            controller: mobileController,
            label: selected == _PaymentMethod.jazzcash
                ? 'JazzCash Mobile Number'
                : 'EasyPaisa Mobile Number',
            hint: '03XX-XXXXXXX',
          )
        else
          const _SafepayInfoPanel(),
      ],
    );
  }
}

class _SafepayInfoPanel extends StatelessWidget {
  const _SafepayInfoPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F8A70).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F8A70).withAlpha(80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF1F8A70)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "You'll be redirected to Safepay's secure checkout to "
              'complete your payment by card.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTab(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobilePaymentForm extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _MobilePaymentForm(
      {required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      maxLength: 11,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.phone_android, color: Colors.deepPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}


class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? Colors.deepPurple : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.deepPurple : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.deepPurple : Colors.grey,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
