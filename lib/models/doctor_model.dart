class DoctorModel {
  final String id;
  final String name;
  final String specialty;
  final String qualification;
  final String hospital;
  final String location;
  final double rating;
  final int reviewCount;
  final int experience; // years
  final int patients;
  final String photoUrl;
  final String bio;
  final List<String> availableDays;
  final List<String> availableTimes;
  final double consultationFee;
  final bool isOnlineAvailable;

  const DoctorModel({
    required this.id,
    required this.name,
    required this.specialty,
    this.qualification = '',
    this.hospital = '',
    this.location = '',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.experience = 0,
    this.patients = 0,
    this.photoUrl = '',
    this.bio = '',
    this.availableDays = const [],
    this.availableTimes = const [],
    this.consultationFee = 0,
    this.isOnlineAvailable = true,
  });

  factory DoctorModel.fromMap(String id, Map<String, dynamic> d) => DoctorModel(
        id: id,
        name: d['name'] ?? '',
        specialty: d['specialty'] ?? '',
        qualification: d['qualification'] ?? '',
        hospital: d['hospital'] ?? '',
        location: d['location'] ?? '',
        rating: (d['rating'] as num? ?? 0.0).toDouble(),
        // Read as num then convert — cloud_firestore_web hands whole
        // numbers back as double, so a bare `?? 0` assigned to an int
        // field throws on web even though it works on Android/iOS.
        reviewCount: (d['reviewCount'] as num? ?? 0).toInt(),
        experience: (d['experience'] as num? ?? 0).toInt(),
        patients: (d['patients'] as num? ?? 0).toInt(),
        photoUrl: d['photoUrl'] ?? '',
        bio: d['bio'] ?? '',
        availableDays: List<String>.from(d['availableDays'] ?? []),
        availableTimes: List<String>.from(d['availableTimes'] ?? []),
        consultationFee: (d['consultationFee'] ?? 0).toDouble(),
        isOnlineAvailable: d['isOnlineAvailable'] ?? true,
      );
}

/// Demo doctors shown when Firestore has no data yet.
final List<DoctorModel> demoDoctors = [
  const DoctorModel(
    id: 'demo_1',
    name: 'Dr. Aisha Khan',
    specialty: 'Psychiatrist',
    qualification: 'MBBS, MRCPsych',
    hospital: 'Aga Khan University Hospital',
    location: 'Karachi, Pakistan',
    rating: 4.9,
    reviewCount: 312,
    experience: 12,
    patients: 2400,
    bio:
        'Dr. Aisha Khan is a certified psychiatrist specializing in anxiety, depression, and stress-related disorders. She believes in a holistic, patient-centered approach.',
    availableDays: ['Mon', 'Tue', 'Wed', 'Thu'],
    availableTimes: ['09:00', '10:00', '11:00', '14:00', '15:00'],
    consultationFee: 3000,
    isOnlineAvailable: true,
  ),
  const DoctorModel(
    id: 'demo_2',
    name: 'Dr. Bilal Raza',
    specialty: 'Neurologist',
    qualification: 'MBBS, FCPS (Neurology)',
    hospital: 'Shaukat Khanum Memorial',
    location: 'Lahore, Pakistan',
    rating: 4.7,
    reviewCount: 198,
    experience: 9,
    patients: 1800,
    bio:
        'Dr. Bilal Raza specializes in headache disorders including migraines and cluster headaches. He uses the latest evidence-based treatments to help patients.',
    availableDays: ['Mon', 'Wed', 'Fri'],
    availableTimes: ['10:00', '11:00', '15:00', '16:00'],
    consultationFee: 2500,
    isOnlineAvailable: true,
  ),
  const DoctorModel(
    id: 'demo_3',
    name: 'Dr. Sara Malik',
    specialty: 'Clinical Psychologist',
    qualification: 'PhD Psychology',
    hospital: 'CMH Rawalpindi',
    location: 'Rawalpindi, Pakistan',
    rating: 4.8,
    reviewCount: 275,
    experience: 8,
    patients: 2100,
    bio:
        'Dr. Sara Malik provides CBT, mindfulness, and counselling sessions for stress, anxiety, and depression. She is known for her empathetic approach.',
    availableDays: ['Tue', 'Thu', 'Sat'],
    availableTimes: ['09:00', '10:30', '12:00', '14:00'],
    consultationFee: 2000,
    isOnlineAvailable: true,
  ),
  const DoctorModel(
    id: 'demo_4',
    name: 'Dr. Omar Sheikh',
    specialty: 'Psychiatrist',
    qualification: 'MBBS, FCPS (Psychiatry)',
    hospital: 'Jinnah Hospital',
    location: 'Karachi, Pakistan',
    rating: 4.6,
    reviewCount: 140,
    experience: 6,
    patients: 1200,
    bio:
        'Dr. Omar Sheikh offers comprehensive psychiatric evaluations and management for mood disorders, schizophrenia, and addiction.',
    availableDays: ['Mon', 'Tue', 'Thu', 'Fri'],
    availableTimes: ['09:00', '11:00', '14:00', '16:00'],
    consultationFee: 2200,
    isOnlineAvailable: false,
  ),
];
