import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/call_service.dart';

/// Active/outgoing/incoming video call UI. Construct with [callId] already
/// created (outgoing: caller made it before pushing this screen; incoming:
/// caller's doc is answered right as this screen opens) so this widget only
/// ever deals with an in-progress signaling exchange, never call creation
/// itself.
class CallScreen extends StatefulWidget {
  final CallService service;
  final String callId;
  final String otherPartyName;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.service,
    required this.callId,
    required this.otherPartyName,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  bool _hasRemoteVideo = false;

  CallStatus _status = CallStatus.ringing;
  bool _muted = false;
  bool _camOff = false;
  bool _timerStarted = false;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  StreamSubscription? _callSub;
  StreamSubscription? _remoteStreamSub;
  bool _endedRemotely = false;

  @override
  void initState() {
    super.initState();
    _init();
    _callSub = widget.service.onCallUpdate.listen(_onCallUpdate);
    _remoteStreamSub = widget.service.onRemoteStream.listen((stream) {
      _remoteRenderer.srcObject = stream;
      if (mounted) setState(() => _hasRemoteVideo = true);
    });
    Permission.camera.request();
    Permission.microphone.request();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _localRenderer.srcObject = widget.service.localStream;
    if (widget.service.remoteStream != null) {
      _remoteRenderer.srcObject = widget.service.remoteStream;
      _hasRemoteVideo = true;
    }
    if (mounted) setState(() => _renderersReady = true);
  }

  void _onCallUpdate(CallSnapshot snap) {
    if (snap.callId != widget.callId) return;
    setState(() => _status = snap.status);

    if (snap.status == CallStatus.ongoing && !_timerStarted) {
      _timerStarted = true;
      final startedAt = snap.data['startedAt'];
      _startedAt = startedAt is Timestamp ? startedAt.toDate() : DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
    }

    if (snap.status == CallStatus.ended || snap.status == CallStatus.declined) {
      if (!_endedRemotely) {
        _endedRemotely = true;
        _cleanupAndClose(alreadyEndedInFirestore: true);
      }
    }
  }

  Future<void> _cleanupAndClose({bool alreadyEndedInFirestore = false}) async {
    _ticker?.cancel();
    if (!alreadyEndedInFirestore) {
      await widget.service.endCall();
    } else {
      await widget.service.dispose();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    final audioTracks = widget.service.localStream?.getAudioTracks() ?? const [];
    if (audioTracks.isEmpty) return;
    setState(() => _muted = !_muted);
    audioTracks.first.enabled = !_muted;
  }

  void _toggleCamera() {
    final videoTracks = widget.service.localStream?.getVideoTracks() ?? const [];
    if (videoTracks.isEmpty) return;
    setState(() => _camOff = !_camOff);
    videoTracks.first.enabled = !_camOff;
  }

  void _switchCamera() {
    final videoTracks = widget.service.localStream?.getVideoTracks() ?? const [];
    if (videoTracks.isEmpty) return;
    Helper.switchCamera(videoTracks.first);
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusLabel {
    switch (_status) {
      case CallStatus.ringing:
        return widget.isCaller ? 'Calling...' : 'Connecting...';
      case CallStatus.ongoing:
        return _formatElapsed(_elapsed);
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.declined:
        return 'Call declined';
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _remoteStreamSub?.cancel();
    _ticker?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _cleanupAndClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _hasRemoteVideo && _renderersReady
                    ? RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : _WaitingAvatar(name: widget.otherPartyName),
              ),
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      widget.otherPartyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
              ),
              if (_renderersReady && !_camOff)
                Positioned(
                  top: 90,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 110,
                      height: 150,
                      color: Colors.black54,
                      child: RTCVideoView(
                        _localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CallActionButton(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      background: Colors.white24,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 20),
                    _CallActionButton(
                      icon: _camOff ? Icons.videocam_off : Icons.videocam,
                      background: Colors.white24,
                      onTap: _toggleCamera,
                    ),
                    const SizedBox(width: 20),
                    _CallActionButton(
                      icon: Icons.cameraswitch,
                      background: Colors.white24,
                      onTap: _switchCamera,
                    ),
                    const SizedBox(width: 20),
                    _CallActionButton(
                      icon: Icons.call_end,
                      background: Colors.red,
                      onTap: () => _cleanupAndClose(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingAvatar extends StatelessWidget {
  final String name;
  const _WaitingAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: CircleAvatar(
          radius: 56,
          backgroundColor: Colors.white24,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 40, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
