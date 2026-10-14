import 'package:flutter/material.dart';

import '../../models/doctor_model.dart';
import 'book_appointment_screen.dart';

class DoctorDetailScreen extends StatelessWidget {
  final DoctorModel doctor;
  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with gradient
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.deepPurple.shade600,
                      Colors.deepPurple.shade300,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // Avatar
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: doctor.photoUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(doctor.photoUrl,
                                    fit: BoxFit.cover))
                            : const Icon(Icons.person,
                                size: 50, color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        doctor.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        doctor.specialty,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _Stat(
                          icon: Icons.star,
                          iconColor: Colors.amber,
                          value: '${doctor.rating}',
                          label: 'Rating'),
                      _Stat(
                          icon: Icons.people_outline,
                          iconColor: Colors.blue,
                          value: '${doctor.patients}+',
                          label: 'Patients'),
                      _Stat(
                          icon: Icons.work_outline,
                          iconColor: Colors.green,
                          value: '${doctor.experience} yrs',
                          label: 'Experience'),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Qualification & Hospital
                  _InfoRow(
                      icon: Icons.school_outlined,
                      text: doctor.qualification),
                  const SizedBox(height: 6),
                  _InfoRow(
                      icon: Icons.local_hospital_outlined,
                      text: doctor.hospital),
                  const SizedBox(height: 6),
                  _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: doctor.location),
                  const SizedBox(height: 18),

                  // Bio
                  const Text('About',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(doctor.bio,
                      style: TextStyle(
                          color: Colors.grey.shade700, height: 1.5)),
                  const SizedBox(height: 18),

                  // Available days
                  const Text('Available Days',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: doctor.availableDays
                        .map((d) => Chip(
                              label: Text(d),
                              backgroundColor:
                                  Colors.deepPurple.shade50,
                              labelStyle: TextStyle(
                                  color: Colors.deepPurple.shade600,
                                  fontWeight: FontWeight.w500),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),

                  // Available times
                  const Text('Available Times',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: doctor.availableTimes
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.deepPurple.shade200),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                      color: Colors.deepPurple.shade600,
                                      fontWeight: FontWeight.w500)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),

                  // Consultation fee
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: Colors.green.shade700),
                        const SizedBox(width: 10),
                        const Text('Consultation Fee',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          'PKR ${doctor.consultationFee.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Book button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BookAppointmentScreen(doctor: doctor),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_outlined,
                          color: Colors.white),
                      label: const Text('Book Appointment',
                          style: TextStyle(
                              fontSize: 16, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _Stat(
      {required this.icon,
      required this.iconColor,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.deepPurple.shade300),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(color: Colors.grey.shade700, fontSize: 14)),
        ),
      ],
    );
  }
}
