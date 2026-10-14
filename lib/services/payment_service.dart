import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';
import 'safepay_client.dart';

/// Result of initiating a Safepay payment: a single checkout URL the
/// WebView navigates to directly.
class SafepayInitResult {
  final String orderRefNum;
  final String checkoutUrl;

  SafepayInitResult({required this.orderRefNum, required this.checkoutUrl});
}

class PaymentStatusResult {
  final String status; // 'initiated' | 'paid' | 'failed' | 'expired'
  final String? transactionId;

  PaymentStatusResult({required this.status, this.transactionId});
}

/// Client-only payment flow (no Cloud Functions backend — see the security
/// note in safepay_client.dart for why). Everything this class does was
/// previously done by a Cloud Function with the Admin SDK; here it's done
/// directly from the app using the current user's own Firestore
/// permissions, per the rules in firestore.rules.
class PaymentService {
  static final _db = FirebaseFirestore.instance;
  static const _redirectUrl = 'smartmind://payment/success';
  static const _cancelUrl = 'smartmind://payment/cancel';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Creates the appointment + payment records and returns the Safepay
  /// hosted checkout URL. The consultation fee is read from the doctor's
  /// Firestore doc at call time — same field the UI displays, so there's
  /// no separate "authoritative" source without a backend to enforce it.
  static Future<SafepayInitResult> initiateSafepayPayment({
    required String doctorId,
    required DateTime dateTime,
    required String mode,
    String? notes,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final doctorSnap = await _db.collection('doctors').doc(doctorId).get();
    if (!doctorSnap.exists) throw Exception('Doctor not found');
    final doctor = doctorSnap.data()!;
    final amount = ((doctor['consultationFee'] as num?) ?? 0).toDouble();
    if (amount <= 0) throw Exception('This doctor has no consultation fee configured.');

    final userSnap = await _db.collection('users').doc(uid).get();
    final user = userSnap.data() ?? {};

    final paymentRef = _db.collection('payments').doc();
    final orderRefNum = paymentRef.id;
    final appointmentRef = _db.collection('appointments').doc();
    final appointmentId = appointmentRef.id;
    final patientAppointmentRef =
        _db.collection('users').doc(uid).collection('appointments').doc(appointmentId);
    final slotRef = _db
        .collection('slotBookings')
        .doc(FirestoreService.slotBookingId(doctorId, dateTime));

    final expiry = DateTime.now().add(const Duration(hours: 1));

    final appointmentData = {
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'doctorName': doctor['name'] ?? '',
      'specialty': doctor['specialty'] ?? '',
      'patientId': uid,
      'patientName': user['name'] ?? '',
      'patientEmail': user['email'] ?? '',
      'patientPhone': user['phone'] ?? '',
      'dateTime': Timestamp.fromDate(dateTime),
      'mode': mode,
      'notes': notes ?? '',
      'status': 'pending_payment',
      'paymentStatus': 'unpaid',
      'amount': amount,
      'orderRefNum': orderRefNum,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final paymentData = {
      'orderRefNum': orderRefNum,
      'appointmentId': appointmentId,
      'patientId': uid,
      'doctorId': doctorId,
      'amount': amount,
      'currency': 'PKR',
      'provider': 'safepay',
      'status': 'initiated',
      'safepayTracker': null,
      'transactionId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'paidAt': null,
      'failedAt': null,
      'expiryDate': Timestamp.fromDate(expiry),
    };

    // Claiming the slot lock happens here, before checkout even starts — the
    // lock exists precisely to hold the slot while the patient is on
    // Safepay's page, not just once payment succeeds. A transaction (rather
    // than the previous plain batch) means a slot someone else just grabbed
    // is caught here instead of silently double-booked.
    await _db.runTransaction((tx) async {
      final slotSnap = await tx.get(slotRef);
      if (slotSnap.exists) {
        throw Exception(
            'This time slot was just booked by someone else. Please choose another time.');
      }
      tx.set(paymentRef, paymentData);
      tx.set(appointmentRef, appointmentData);
      tx.set(patientAppointmentRef, appointmentData);
      tx.set(slotRef, {
        'doctorId': doctorId,
        'date': FirestoreService.slotDateKey(dateTime),
        'time': FirestoreService.slotTimeKey(dateTime),
        'appointmentId': appointmentId,
        'patientId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    try {
      final tracker = await SafepayClient.createSession(
        amount: amount,
        orderId: orderRefNum,
      );
      final tbt = await SafepayClient.getPassportToken();
      await paymentRef.update({'safepayTracker': tracker});

      final checkoutUrl = SafepayClient.buildCheckoutUrl(
        tracker: tracker,
        tbt: tbt,
        orderId: orderRefNum,
        redirectUrl: _redirectUrl,
        cancelUrl: _cancelUrl,
      );

      return SafepayInitResult(orderRefNum: orderRefNum, checkoutUrl: checkoutUrl);
    } catch (e) {
      await paymentRef.update({'status': 'failed'});
      await appointmentRef.update({'status': 'failed', 'paymentStatus': 'failed'});
      await patientAppointmentRef.update({'status': 'failed', 'paymentStatus': 'failed'});
      await slotRef.delete();
      rethrow;
    }
  }

  /// Called when the patient backs out of Safepay's checkout page without
  /// paying. Without this, the slot lock claimed in initiateSafepayPayment
  /// would stay held forever, permanently burning that slot.
  static Future<void> cancelPendingPayment(String orderRefNum) async {
    final paymentRef = _db.collection('payments').doc(orderRefNum);
    final snap = await paymentRef.get();
    final payment = snap.data();
    if (payment == null) return;
    if (payment['status'] == 'paid' || payment['status'] == 'failed') return;
    await _applyResult(orderRefNum, payment, 'failed', null);
  }

  /// Calls Safepay directly to check the real status of a payment, then
  /// applies the result to Firestore. This is now the ONLY way a payment
  /// ever gets marked paid — called after the WebView's redirect fires
  /// (as a trigger, not as the source of truth) and via the manual
  /// "Check status" button.
  static Future<PaymentStatusResult> checkSafepayStatus(String orderRefNum) async {
    final paymentRef = _db.collection('payments').doc(orderRefNum);
    final snap = await paymentRef.get();
    if (!snap.exists) throw Exception('Payment not found');
    final payment = snap.data()!;

    if (payment['status'] == 'paid' || payment['status'] == 'failed') {
      return PaymentStatusResult(
        status: payment['status'] as String,
        transactionId: payment['transactionId'] as String?,
      );
    }

    final expiry = payment['expiryDate'] as Timestamp?;
    if (expiry != null && expiry.toDate().isBefore(DateTime.now())) {
      await _applyResult(orderRefNum, payment, 'failed', null);
      return PaymentStatusResult(status: 'failed');
    }

    final tracker = payment['safepayTracker'] as String?;
    if (tracker == null) {
      return PaymentStatusResult(status: 'initiated');
    }

    try {
      final (state, _) = await SafepayClient.fetchStatus(tracker);
      String? outcome;
      if (state == 'TRACKER_ENDED') outcome = 'paid';
      if (state == 'TRACKER_CANCELLED' || state == 'TRACKER_EXPIRED') outcome = 'failed';

      if (outcome == null) return PaymentStatusResult(status: 'initiated');

      await _applyResult(orderRefNum, payment, outcome, tracker);
      return PaymentStatusResult(status: outcome, transactionId: tracker);
    } catch (e) {
      return PaymentStatusResult(status: 'initiated');
    }
  }

  static Future<void> _applyResult(String orderRefNum, Map<String, dynamic> payment,
      String outcome, String? transactionId) async {
    final appointmentId = payment['appointmentId'] as String;
    final patientId = payment['patientId'] as String;
    final doctorId = payment['doctorId'] as String?;
    final now = FieldValue.serverTimestamp();

    final paymentUpdate = {
      'status': outcome,
      'transactionId': transactionId,
      if (outcome == 'paid') 'paidAt': now else 'failedAt': now,
    };
    // 'paid' confirms the appointment directly — no separate doctor
    // confirmation step. 'failed' releases the slot lock below so the time
    // becomes bookable again instead of being burned by a failed attempt.
    final appointmentUpdate = {
      'paymentStatus': outcome,
      'status': outcome == 'paid' ? 'confirmed' : 'failed',
      'updatedAt': now,
    };

    final batch = _db.batch();
    batch.update(_db.collection('payments').doc(orderRefNum), paymentUpdate);
    batch.set(_db.collection('appointments').doc(appointmentId), appointmentUpdate,
        SetOptions(merge: true));
    batch.set(
        _db.collection('users').doc(patientId).collection('appointments').doc(appointmentId),
        appointmentUpdate,
        SetOptions(merge: true));
    await batch.commit();

    if (outcome == 'failed' && doctorId != null) {
      final appointmentSnap =
          await _db.collection('appointments').doc(appointmentId).get();
      final ts = appointmentSnap.data()?['dateTime'];
      if (ts is Timestamp) {
        await _db
            .collection('slotBookings')
            .doc(FirestoreService.slotBookingId(doctorId, ts.toDate()))
            .delete();
      }
    }
  }

  /// Streams the payment doc so the checkout screen can watch its status.
  static Stream<PaymentStatusResult?> watchPaymentStatus(String orderRefNum) {
    return _db.collection('payments').doc(orderRefNum).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return PaymentStatusResult(
        status: data['status'] as String,
        transactionId: data['transactionId'] as String?,
      );
    });
  }
}
