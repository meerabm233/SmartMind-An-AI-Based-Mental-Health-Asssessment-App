import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assessment_result.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ────────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────────

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> _resultsCol(String uid) =>
      _userDoc(uid).collection('assessments');

  static CollectionReference<Map<String, dynamic>> get _doctorsCol =>
      _db.collection('doctors');

    static CollectionReference<Map<String, dynamic>> get _appointmentsRootCol =>
      _db.collection('appointments');

  static CollectionReference<Map<String, dynamic>> get _slotBookingsCol =>
      _db.collection('slotBookings');

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// 'yyyyMMdd' for a given date — used both as the slot lock's `date` field
  /// and to scope the booking screen's live availability query to one day.
  static String slotDateKey(DateTime dt) =>
      '${dt.year}${_pad2(dt.month)}${_pad2(dt.day)}';

  /// 'HH:mm' — matches the format doctors already store in `availableTimes`
  /// (see DoctorSlotsScreen._addTimeSlot), so slot times compare directly.
  static String slotTimeKey(DateTime dt) => '${_pad2(dt.hour)}:${_pad2(dt.minute)}';

  /// Deterministic lock-doc id for one doctor + exact date/time. Computing
  /// this the same way at booking time and at release time (cancel/fail) is
  /// what lets a transaction use it as a real mutual-exclusion lock.
  static String slotBookingId(String doctorId, DateTime dt) =>
      '${doctorId}_${slotDateKey(dt)}_${slotTimeKey(dt)}';

  // ────────────────────────────────────────────────────────────────────────
  // User Profile
  // ────────────────────────────────────────────────────────────────────────

  /// Create or overwrite user profile document.
  static Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String email,
    String role = 'patient',
    String phone = '',
    String age = '',
    String gender = '',
    String photoUrl = '',
  }) async {
    await _userDoc(uid).set({
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'age': age,
      'gender': gender,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch profile for current user.
  static Future<Map<String, String>> getUserProfile() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _userDoc(uid).get();
    if (!snap.exists) return {};
    final d = snap.data()!;
    return {
      'name': d['name'] ?? '',
      'email': d['email'] ?? '',
      'role': d['role'] ?? 'patient',
      'phone': d['phone'] ?? '',
      'age': d['age'] ?? '',
      'gender': d['gender'] ?? '',
      'photoUrl': d['photoUrl'] ?? '',
    };
  }

  static Future<String> getCurrentUserRole() async {
    final uid = _uid;
    if (uid == null) return 'patient';
    final snap = await _userDoc(uid).get();
    if (!snap.exists) return 'patient';
    final d = snap.data()!;
    return (d['role'] ?? 'patient').toString();
  }

  static Future<void> saveDoctorProfile({
    required String uid,
    required String name,
    required String email,
    required String specialty,
    String qualification = '',
    String hospital = '',
    String location = '',
    String phone = '',
    String bio = '',
    bool isOnlineAvailable = true,
    List<String> availableDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    List<String> availableTimes = const ['09:00', '10:00', '11:00', '14:00'],
    double consultationFee = 2000,
  }) async {
    await _doctorsCol.doc(uid).set({
      'name': name,
      'email': email,
      'specialty': specialty,
      'qualification': qualification,
      'hospital': hospital,
      'location': location,
      'phone': phone,
      'bio': bio,
      'isOnlineAvailable': isOnlineAvailable,
      'availableDays': availableDays,
      'availableTimes': availableTimes,
      'consultationFee': consultationFee,
      'rating': 0,
      'reviewCount': 0,
      'experience': 0,
      'patients': 0,
      'photoUrl': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ────────────────────────────────────────────────────────────────────────
  // Assessments  (DASS-21 + Headache combined)
  // ────────────────────────────────────────────────────────────────────────

  /// Save a completed assessment result.
  static Future<void> saveAssessmentResult(AssessmentResult result) async {
    final uid = _uid;
    // If user is not logged in, persist the result locally so it can be
    // synced later when the user signs in.
    if (uid == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final pending = prefs.getStringList('pending_assessments') ?? [];
        pending.add(jsonEncode({
          'dass21Answers': result.dass21Answers,
          'depressionScore': result.depressionScore,
          'anxietyScore': result.anxietyScore,
          'stressScore': result.stressScore,
          'depressionLevel': result.depressionLevel,
          'anxietyLevel': result.anxietyLevel,
          'stressLevel': result.stressLevel,
          'headacheType': result.headacheType,
          'headacheFrequency': result.headacheFrequency,
          'headacheSeverity': result.headacheSeverity,
          'headacheDuration': result.headacheDuration,
          'headacheSeverityLabel': result.headacheSeverityLabel,
          'createdAt': DateTime.now().toIso8601String(),
        }));
        await prefs.setStringList('pending_assessments', pending);
      } catch (_) {}
      return;
    }

    await _resultsCol(uid).add({
      // DASS-21
      'dass21Answers': result.dass21Answers,
      'depressionScore': result.depressionScore,
      'anxietyScore': result.anxietyScore,
      'stressScore': result.stressScore,
      'depressionLevel': result.depressionLevel,
      'anxietyLevel': result.anxietyLevel,
      'stressLevel': result.stressLevel,
      // Headache
      'headacheType': result.headacheType,
      'headacheFrequency': result.headacheFrequency,
      'headacheSeverity': result.headacheSeverity,
      'headacheDuration': result.headacheDuration,
      'headacheSeverityLabel': result.headacheSeverityLabel,
      // Meta
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Flush saved local assessments into Firestore for the current user.
  static Future<void> syncPendingAssessments() async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_assessments') ?? [];
    if (pending.isEmpty) return;
    for (final item in pending) {
      try {
        final Map<String, dynamic> d = jsonDecode(item);
        // Convert createdAt back to server timestamp by excluding it.
        await _resultsCol(uid).add({
          'dass21Answers': List<int>.from(d['dass21Answers'] ?? []),
          'depressionScore': d['depressionScore'] ?? 0,
          'anxietyScore': d['anxietyScore'] ?? 0,
          'stressScore': d['stressScore'] ?? 0,
          'depressionLevel': d['depressionLevel'] ?? '',
          'anxietyLevel': d['anxietyLevel'] ?? '',
          'stressLevel': d['stressLevel'] ?? '',
          'headacheType': d['headacheType'] ?? '',
          'headacheFrequency': d['headacheFrequency'] ?? '',
          'headacheSeverity': d['headacheSeverity'] ?? 0,
          'headacheDuration': d['headacheDuration'] ?? '',
          'headacheSeverityLabel': d['headacheSeverityLabel'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // ignore malformed entry
      }
    }
    await prefs.remove('pending_assessments');
  }

  /// Fetch all assessment results for current user (newest first).
  static Future<List<Map<String, dynamic>>> getAssessmentHistory() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _resultsCol(uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Fetch a specific patient's most recent DASS-21/headache assessment,
  /// for a doctor reviewing an appointment. Returns null if the patient has
  /// never completed one.
  static Future<Map<String, dynamic>?> getLatestAssessmentForPatient(
      String patientId) async {
    final snap = await _resultsCol(patientId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  // ────────────────────────────────────────────────────────────────────────
  // Headache-only entries (standalone module)
  // ────────────────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _headachesCol(String uid) =>
      _userDoc(uid).collection('headaches');

  static Future<void> saveHeadacheEntry({
    required String type,
    required String frequency,
    required int severity,
    required String duration,
    String? notes,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    await _headachesCol(uid).add({
      'type': type,
      'frequency': frequency,
      'severity': severity,
      'duration': duration,
      'notes': notes ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getHeadacheHistory() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _headachesCol(uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Doctors  (read-only from admin-populated collection)
  // ────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDoctorProfile() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _doctorsCol.doc(uid).get();
    if (!snap.exists) return {};
    return {'id': snap.id, ...snap.data()!};
  }

  static Future<void> updateDoctorSlots({
    required List<String> availableDays,
    required List<String> availableTimes,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    await _doctorsCol.doc(uid).set({
      'availableDays': availableDays,
      'availableTimes': availableTimes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateDoctorProfile({
    String? name,
    String? specialty,
    String? qualification,
    String? hospital,
    String? location,
    String? phone,
    String? bio,
    bool? isOnlineAvailable,
    double? consultationFee,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (specialty != null) updates['specialty'] = specialty;
    if (qualification != null) updates['qualification'] = qualification;
    if (hospital != null) updates['hospital'] = hospital;
    if (location != null) updates['location'] = location;
    if (phone != null) updates['phone'] = phone;
    if (bio != null) updates['bio'] = bio;
    if (isOnlineAvailable != null) updates['isOnlineAvailable'] = isOnlineAvailable;
    if (consultationFee != null) updates['consultationFee'] = consultationFee;
    await _doctorsCol.doc(uid).set(updates, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> getDoctors({
    String? specialty,
  }) async {
    Query<Map<String, dynamic>> q = _doctorsCol;
    if (specialty != null && specialty != 'All') {
      q = q.where('specialty', isEqualTo: specialty);
    }
    final snap = await q.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Appointments
  // ────────────────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _appointmentsCol(
          String uid) =>
      _userDoc(uid).collection('appointments');

  /// Mock JazzCash/EasyPaisa "payment" — since there's no real gateway
  /// behind these, success is immediate and the appointment is confirmed
  /// directly, same as a successful Safepay payment (see
  /// PaymentService._applyResult). Runs as a transaction so claiming the
  /// slot lock and creating the appointment either both happen or neither
  /// does, and so a slot taken by a concurrent booking is detected rather
  /// than silently double-booked.
  static Future<void> bookAppointment({
    required String doctorId,
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String mode, // 'Online' | 'In-Person'
    String? notes,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final user = await getUserProfile();
    final rootDoc = _appointmentsRootCol.doc();
    final slotRef = _slotBookingsCol.doc(slotBookingId(doctorId, dateTime));

    final data = {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'patientId': uid,
      'patientName': user['name'] ?? '',
      'patientEmail': user['email'] ?? '',
      'patientPhone': user['phone'] ?? '',
      'dateTime': Timestamp.fromDate(dateTime),
      'mode': mode,
      'notes': notes ?? '',
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _db.runTransaction((tx) async {
      final slotSnap = await tx.get(slotRef);
      if (slotSnap.exists) {
        throw Exception(
            'This time slot was just booked by someone else. Please choose another time.');
      }
      tx.set(rootDoc, {'appointmentId': rootDoc.id, ...data});
      tx.set(_appointmentsCol(uid).doc(rootDoc.id), {
        'appointmentId': rootDoc.id,
        ...data,
      });
      tx.set(slotRef, {
        'doctorId': doctorId,
        'date': slotDateKey(dateTime),
        'time': slotTimeKey(dateTime),
        'appointmentId': rootDoc.id,
        'patientId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Stream of taken time strings ('HH:mm') for one doctor on one day, for
  /// the booking screen to subtract from the doctor's recurring
  /// availableTimes template. Live, not a one-time fetch, so a slot taken by
  /// someone else disappears from an already-open booking screen.
  static Stream<Set<String>> watchTakenSlotTimes(
      String doctorId, DateTime date) {
    return _slotBookingsCol
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isEqualTo: slotDateKey(date))
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => (d.data()['time'] ?? '').toString()).toSet());
  }

  static Future<List<Map<String, dynamic>>> getMyAppointments() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _appointmentsCol(uid)
        .orderBy('dateTime', descending: false)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<List<Map<String, dynamic>>> getDoctorAppointments() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _appointmentsRootCol
        .where('doctorId', isEqualTo: uid)
        .orderBy('dateTime')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<void> updateAppointmentByDoctor({
    required String appointmentId,
    required String status,
    String meetingLink = '',
    String doctorNote = '',
  }) async {
    final doc = await _appointmentsRootCol.doc(appointmentId).get();
    if (!doc.exists) throw Exception('Appointment not found');
    final data = doc.data()!;
    final patientId = (data['patientId'] ?? '').toString();

    final updates = {
      'status': status,
      'meetingLink': meetingLink,
      'doctorNote': doctorNote,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _appointmentsRootCol.doc(appointmentId).set(updates, SetOptions(merge: true));
    if (patientId.isNotEmpty) {
      await _appointmentsCol(patientId)
          .doc(appointmentId)
          .set(updates, SetOptions(merge: true));
    }

    // Cancelling frees the slot back up for other patients to book.
    if (status == 'cancelled') {
      final doctorId = (data['doctorId'] ?? '').toString();
      final ts = data['dateTime'];
      if (doctorId.isNotEmpty && ts is Timestamp) {
        await _slotBookingsCol
            .doc(slotBookingId(doctorId, ts.toDate()))
            .delete();
      }
    }
  }

  static Future<void> doctorCreateAppointmentForPatient({
    required String patientEmail,
    required DateTime dateTime,
    required String mode,
    String notes = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final patientSnap = await _db
        .collection('users')
        .where('email', isEqualTo: patientEmail.trim())
        .limit(1)
        .get();
    if (patientSnap.docs.isEmpty) {
      throw Exception('Patient not found for this email');
    }
    final patientDoc = patientSnap.docs.first;
    final patient = patientDoc.data();

    final doctorDoc = await _doctorsCol.doc(uid).get();
    if (!doctorDoc.exists) {
      throw Exception('Doctor profile not found. Complete doctor signup first.');
    }
    final doctor = doctorDoc.data()!;

    final rootDoc = _appointmentsRootCol.doc();
    final data = {
      'doctorId': uid,
      'doctorName': doctor['name'] ?? '',
      'specialty': doctor['specialty'] ?? '',
      'patientId': patientDoc.id,
      'patientName': patient['name'] ?? '',
      'patientEmail': patient['email'] ?? patientEmail.trim(),
      'patientPhone': patient['phone'] ?? '',
      'dateTime': Timestamp.fromDate(dateTime),
      'mode': mode,
      'notes': notes,
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await rootDoc.set({'appointmentId': rootDoc.id, ...data});
    await _appointmentsCol(patientDoc.id).doc(rootDoc.id).set({
      'appointmentId': rootDoc.id,
      ...data,
    });
  }
}
