import 'package:flutter/material.dart';

import '../../services/call_service.dart';

/// Shows the most recent completed call's duration for an appointment, if
/// any — reference info for the doctor/patient, not tied to billing amount.
class CallDurationBadge extends StatelessWidget {
  final String appointmentId;
  const CallDurationBadge({super.key, required this.appointmentId});

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: CallService.getLastCallDuration(appointmentId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data == null) {
          return const SizedBox.shrink();
        }
        return Row(
          children: [
            Icon(Icons.call_outlined, size: 15, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Last call duration: ${_format(snap.data!)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        );
      },
    );
  }
}
