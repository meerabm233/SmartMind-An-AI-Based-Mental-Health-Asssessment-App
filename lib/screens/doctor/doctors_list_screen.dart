import 'package:flutter/material.dart';

import '../../models/doctor_model.dart';
import '../../services/firestore_service.dart';
import 'doctor_detail_screen.dart';

class DoctorsListScreen extends StatefulWidget {
  const DoctorsListScreen({super.key});

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  static const _specialties = [
    'All',
    'Psychiatrist',
    'Neurologist',
    'Clinical Psychologist',
  ];

  String _selectedSpecialty = 'All';
  String _search = '';
  List<DoctorModel> _doctors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FirestoreService.getDoctors(
          specialty: _selectedSpecialty == 'All' ? null : _selectedSpecialty);
      final models = data.map((d) => DoctorModel.fromMap(d['id'], d)).toList();
      if (models.isEmpty) {
        // Use demo data when Firestore has no doctors yet
        setState(() {
          _doctors = _selectedSpecialty == 'All'
              ? demoDoctors
              : demoDoctors
                  .where((d) => d.specialty == _selectedSpecialty)
                  .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _doctors = models;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _doctors = demoDoctors;
        _loading = false;
      });
    }
  }

  List<DoctorModel> get _filtered {
    if (_search.isEmpty) return _doctors;
    final q = _search.toLowerCase();
    return _doctors
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.specialty.toLowerCase().contains(q) ||
            d.hospital.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name, specialty, or hospital...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Specialty filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _specialties.map((s) {
                final selected = _selectedSpecialty == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedSpecialty = s);
                      _load();
                    },
                    selectedColor: Colors.deepPurple.shade100,
                    checkmarkColor: Colors.deepPurple,
                  ),
                );
              }).toList(),
            ),
          ),

          // Doctor list
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            const Expanded(
                child: Center(child: Text('No doctors found.')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _DoctorCard(doctor: _filtered[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DoctorDetailScreen(doctor: doctor)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  shape: BoxShape.circle,
                ),
                child: doctor.photoUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(doctor.photoUrl,
                            fit: BoxFit.cover))
                    : Icon(Icons.person,
                        size: 36, color: Colors.deepPurple.shade300),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(doctor.specialty,
                        style: TextStyle(
                            color: Colors.deepPurple.shade400,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(doctor.hospital,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text('${doctor.rating}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Text(' (${doctor.reviewCount})',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        const SizedBox(width: 12),
                        Icon(Icons.work_outline,
                            size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Text('${doctor.experience} yrs',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),

              // Online badge
              if (doctor.isOnlineAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text('Online',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
