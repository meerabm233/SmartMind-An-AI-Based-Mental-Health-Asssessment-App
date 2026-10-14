import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/call_service.dart';
import 'call_screen.dart';

/// Wrap a shell screen (MainNavScreen for patients, DoctorDashboardScreen
/// for doctors) with this to surface a ringing-call banner while the app is
/// foregrounded. There's no push/FCM wiring in this app yet, so incoming
/// calls only ring while this widget is mounted and visible — a known,
/// accepted limitation (see the calling feature's plan doc).
class IncomingCallListener extends StatefulWidget {
  final Widget child;
  const IncomingCallListener({super.key, required this.child});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _asDoctorSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _asPatientSub;
  final Set<String> _handledCallIds = {};
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _asDoctorSub =
        CallService.listenForIncomingCallsAsDoctor().listen(_onSnapshot);
    _asPatientSub =
        CallService.listenForIncomingCallsAsPatient().listen(_onSnapshot);
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (_dialogShowing) return;
    for (final doc in snap.docs) {
      if (_handledCallIds.contains(doc.id)) continue;
      _handledCallIds.add(doc.id);
      _showIncomingCallDialog(doc.id, doc.data());
      break; // one at a time
    }
  }

  Future<void> _showIncomingCallDialog(
      String callId, Map<String, dynamic> data) async {
    final selfUid = FirebaseAuth.instance.currentUser?.uid;
    if (selfUid == null) return;
    final doctorUid = (data['doctorId'] ?? '').toString();
    final isSelfDoctor = selfUid == doctorUid;
    final callerName = isSelfDoctor
        ? (data['patientName'] ?? 'Patient').toString()
        : (data['doctorName'] ?? 'Doctor').toString();

    _dialogShowing = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Incoming call'),
        content: Text('$callerName is calling you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    _dialogShowing = false;

    if (accepted != true) {
      await CallService.declineCall(callId);
      return;
    }
    if (!mounted) return;

    final service = CallService();
    try {
      await service.answerCall(callId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join call: $e')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          service: service,
          callId: callId,
          otherPartyName: callerName,
          isCaller: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _asDoctorSub?.cancel();
    _asPatientSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
