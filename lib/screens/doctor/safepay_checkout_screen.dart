import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/payment_service.dart';

enum SafepayCheckoutOutcome { paid, failed, cancelled }

class SafepayCheckoutResult {
  final SafepayCheckoutOutcome outcome;
  const SafepayCheckoutResult(this.outcome);
}

/// Hosts Safepay's checkout page in a WebView and waits for the payment
/// outcome.
///
/// There's no backend to receive a verified webhook (see the security note
/// in safepay_client.dart), so the redirect to `smartmind://payment/...`
/// is used as a TRIGGER to call Safepay's status API directly — the
/// redirect itself is never trusted as the outcome, only as a signal to
/// go ask Safepay what actually happened.
class SafepayCheckoutScreen extends StatefulWidget {
  final String orderRefNum;
  final String checkoutUrl;

  const SafepayCheckoutScreen({
    super.key,
    required this.orderRefNum,
    required this.checkoutUrl,
  });

  @override
  State<SafepayCheckoutScreen> createState() => _SafepayCheckoutScreenState();
}

class _SafepayCheckoutScreenState extends State<SafepayCheckoutScreen> {
  late final WebViewController _controller;
  StreamSubscription<PaymentStatusResult?>? _sub;
  Timer? _timeoutTimer;
  bool _timedOut = false;
  bool _resolving = false;
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();

    // Safepay's hosted checkout is a plain GET-navigable URL (unlike
    // EasyPaisa/JazzCash, which needed a self-submitting POST form) — so
    // the WebView can just load it directly.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (request.url.startsWith('smartmind://payment/')) {
            // Not a real URL — nothing to load. Treat it purely as a
            // signal to go ask Safepay directly what happened.
            _checkStatusNow();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    _sub = PaymentService.watchPaymentStatus(widget.orderRefNum)
        .listen(_onStatusUpdate);

    _timeoutTimer = Timer(const Duration(minutes: 10), () {
      if (!mounted || _resolving) return;
      setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _onStatusUpdate(PaymentStatusResult? result) {
    if (result == null || _resolving) return;
    if (result.status == 'paid') {
      _resolve(SafepayCheckoutOutcome.paid);
    } else if (result.status == 'failed' || result.status == 'expired') {
      _resolve(SafepayCheckoutOutcome.failed);
    }
  }

  void _resolve(SafepayCheckoutOutcome outcome) {
    if (_resolving || !mounted) return;
    _resolving = true;
    Navigator.pop(context, SafepayCheckoutResult(outcome));
  }

  Future<void> _checkStatusNow() async {
    setState(() => _checkingStatus = true);
    try {
      final result =
          await PaymentService.checkSafepayStatus(widget.orderRefNum);
      if (result.status == 'paid') {
        _resolve(SafepayCheckoutOutcome.paid);
      } else if (result.status == 'failed' || result.status == 'expired') {
        _resolve(SafepayCheckoutOutcome.failed);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Still waiting for Safepay to confirm this payment.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safepay Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _resolve(SafepayCheckoutOutcome.cancelled),
        ),
      ),
      body: Column(
        children: [
          if (_timedOut)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text(
                    "Taking longer than expected. If you've already completed "
                    "the payment, tap below to check its status.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _checkingStatus ? null : _checkStatusNow,
                    child: _checkingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Check status'),
                  ),
                ],
              ),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
