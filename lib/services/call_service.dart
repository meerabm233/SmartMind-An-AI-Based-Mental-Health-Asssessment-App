import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Free STUN + TURN (Open Relay Project's public, no-signup relay) — no
/// vendor account needed. Shared/rate-limited, fine for an FYP, not for
/// production scale.
const _iceServers = {
  'iceServers': [
    {
      'urls': ['stun:stun.l.google.com:19302'],
    },
    {
      'urls': ['turn:openrelay.metered.ca:80'],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': ['turn:openrelay.metered.ca:443'],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ],
};

enum CallStatus { ringing, ongoing, ended, declined }

CallStatus _statusFromString(String s) => CallStatus.values.firstWhere(
      (v) => v.name == s,
      orElse: () => CallStatus.ended,
    );

/// One side's live view of a call: connection state plus the Firestore doc
/// data, so the UI can render elapsed time / hang-up reasons without a
/// second listener.
class CallSnapshot {
  final String callId;
  final CallStatus status;
  final Map<String, dynamic> data;
  const CallSnapshot(this.callId, this.status, this.data);
}

/// Owns the RTCPeerConnection + local mic/camera stream for a single call,
/// and the Firestore offer/answer/ICE-candidate signaling exchange
/// (mirrors FirestoreService's static-service style).
class CallService {
  static final _db = FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _callsCol =>
      _db.collection('calls');

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _callId;
  bool _isCaller = false;

  StreamSubscription? _callDocSub;
  StreamSubscription? _remoteCandidatesSub;

  final _callStateController = StreamController<CallSnapshot>.broadcast();
  Stream<CallSnapshot> get onCallUpdate => _callStateController.stream;

  final _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();
  Stream<RTCPeerConnectionState> get onConnectionState =>
      _connectionStateController.stream;

  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;

  String? get activeCallId => _callId;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Live query for calls ringing for the signed-in user — either doctor or
  /// patient side. Two `where` clauses can't be OR'd directly in Firestore,
  /// so this merges two separate ringing-status queries.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      listenForIncomingCallsAsDoctor() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _callsCol
        .where('doctorId', isEqualTo: uid)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
      listenForIncomingCallsAsPatient() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _callsCol
        .where('patientId', isEqualTo: uid)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots();
  }

  /// Caller side: creates the call doc, local media, offer, and starts
  /// streaming local ICE candidates.
  Future<String> startCall({
    required String appointmentId,
    required String doctorId,
    required String patientId,
    required String doctorName,
    required String patientName,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    _isCaller = true;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });

    _pc = await createPeerConnection(_iceServers);
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    final callDoc = _callsCol.doc();
    _callId = callDoc.id;

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream!);
      }
    };
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      callDoc.collection('callerCandidates').add(candidate.toMap());
    };
    _pc!.onConnectionState = (state) {
      _connectionStateController.add(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        callDoc.set({
          'status': CallStatus.ongoing.name,
          'startedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    };

    final offer = await _pc!
        .createOffer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
    await _pc!.setLocalDescription(offer);

    await callDoc.set({
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'patientId': patientId,
      'doctorName': doctorName,
      'patientName': patientName,
      'status': CallStatus.ringing.name,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'createdAt': FieldValue.serverTimestamp(),
    });

    _watchCallDoc(callDoc);
    _remoteCandidatesSub = callDoc
        .collection('calleeCandidates')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _pc?.addCandidate(_candidateFromMap(change.doc.data()!));
        }
      }
    });

    // Answer arrives via the call doc listener (_watchCallDoc), applied
    // there since it needs the doc's other fields too.
    return _callId!;
  }

  /// Callee side: accepts an already-ringing call doc.
  Future<void> answerCall(String callId) async {
    _isCaller = false;
    _callId = callId;
    final callDoc = _callsCol.doc(callId);
    final snap = await callDoc.get();
    final data = snap.data();
    if (data == null) throw Exception('Call not found');
    final offer = data['offer'] as Map<String, dynamic>?;
    if (offer == null) throw Exception('Call has no offer');

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });

    _pc = await createPeerConnection(_iceServers);
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream!);
      }
    };
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      callDoc.collection('calleeCandidates').add(candidate.toMap());
    };
    _pc!.onConnectionState = (state) {
      _connectionStateController.add(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        callDoc.set({
          'status': CallStatus.ongoing.name,
          'startedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    };

    await _pc!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
    );
    final answer = await _pc!
        .createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
    await _pc!.setLocalDescription(answer);

    await callDoc.set({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    }, SetOptions(merge: true));

    _watchCallDoc(callDoc);
    _remoteCandidatesSub = callDoc
        .collection('callerCandidates')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _pc?.addCandidate(_candidateFromMap(change.doc.data()!));
        }
      }
    });
  }

  void _watchCallDoc(DocumentReference<Map<String, dynamic>> callDoc) {
    _callDocSub = callDoc.snapshots().listen((snap) async {
      final data = snap.data();
      if (data == null) return;
      final status = _statusFromString(data['status'] as String? ?? 'ended');
      _callStateController.add(CallSnapshot(callDoc.id, status, data));

      // Caller applies the answer once the callee has written it.
      if (_isCaller && status != CallStatus.declined) {
        final answer = data['answer'] as Map<String, dynamic>?;
        if (answer != null && _pc?.getRemoteDescription() == null) {
          await _pc?.setRemoteDescription(
            RTCSessionDescription(
              answer['sdp'] as String,
              answer['type'] as String,
            ),
          );
        }
      }
    });
  }

  static RTCIceCandidate _candidateFromMap(Map<String, dynamic> m) =>
      RTCIceCandidate(
        m['candidate'] as String?,
        m['sdpMid'] as String?,
        m['sdpMLineIndex'] as int?,
      );

  /// Latest ended call's duration for an appointment, for display on the
  /// appointment card (a doctor's reference for the fixed consultationFee
  /// they already charged — not used to compute any charge itself).
  static Future<int?> getLastCallDuration(String appointmentId) async {
    final snap =
        await _callsCol.where('appointmentId', isEqualTo: appointmentId).get();
    int? best;
    Timestamp? bestEndedAt;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['status'] != CallStatus.ended.name) continue;
      final endedAt = data['endedAt'] as Timestamp?;
      final duration = data['durationSeconds'] as int?;
      if (duration == null) continue;
      if (bestEndedAt == null ||
          (endedAt != null && endedAt.compareTo(bestEndedAt) > 0)) {
        best = duration;
        bestEndedAt = endedAt;
      }
    }
    return best;
  }

  static Future<void> declineCall(String callId) async {
    await _callsCol.doc(callId).set({
      'status': CallStatus.declined.name,
    }, SetOptions(merge: true));
  }

  /// Ends the call: marks it 'ended' with a computed duration, then tears
  /// down the local peer connection/media. Duration is derived from the
  /// call doc's own `startedAt` (server time) so both sides agree on it
  /// even though each computes/writes it independently.
  Future<int?> endCall() async {
    int? durationSeconds;
    if (_callId != null) {
      final callDoc = _callsCol.doc(_callId);
      final snap = await callDoc.get();
      final data = snap.data();
      final startedAt = data?['startedAt'] as Timestamp?;
      if (startedAt != null) {
        durationSeconds = DateTime.now().difference(startedAt.toDate()).inSeconds;
      }
      await callDoc.set({
        'status': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      }, SetOptions(merge: true));
    }
    await dispose();
    return durationSeconds;
  }

  Future<void> dispose() async {
    await _callDocSub?.cancel();
    await _remoteCandidatesSub?.cancel();
    for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    await _pc?.dispose();
    _pc = null;
    _localStream = null;
    _remoteStream = null;
    await _callStateController.close();
    await _connectionStateController.close();
    await _remoteStreamController.close();
  }
}
