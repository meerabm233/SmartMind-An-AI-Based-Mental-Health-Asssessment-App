import 'dart:convert';

import 'package:http/http.dart' as http;

/// Direct client-side Safepay REST client.
///
/// NORMALLY this logic (and the secret key below) would live on a server —
/// see functions/src/safepay/ for the Cloud Functions version of exactly
/// this flow, which is the version to switch back to once a backend is
/// available (Firebase Blaze plan). This client-only version exists
/// because the project currently has no way to run a backend (no card
/// available for Firebase Blaze), so it's a deliberate, known trade-off:
/// the Safepay secret key ships inside the compiled app and is extractable
/// by anyone who decompiles it. Acceptable for a non-production student
/// project; NOT acceptable if this app is ever used to process real
/// payments at any meaningful scale.
class SafepayClient {
  // TODO(security): move these server-side (see functions/src/safepay/)
  // the moment a backend becomes available again.
  static const String _secretKey =
      '0830618d177ebd9fffddc49d99d85de7cc52dcf545063758e839d60633dc3b0f';
  static const String _merchantApiKey = 'sec_6adeee87-8fa7-40b8-8978-233135aca37d';
  static const String _env = 'sandbox'; // 'sandbox' | 'production'

  static const Map<String, String> _hosts = {
    'sandbox': 'https://sandbox.api.getsafepay.com',
    'production': 'https://api.getsafepay.com',
  };

  static const Map<String, String> _checkoutHosts = {
    'sandbox': 'https://sandbox.api.getsafepay.com/embedded/',
    'production': 'https://getsafepay.com/embedded/',
  };

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${_hosts[_env]}$path'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-sfpy-merchant-secret': _secretKey,
      },
      body: jsonEncode(body),
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception('Safepay API error (${res.statusCode}): ${res.body}');
    }
    return json;
  }

  /// Creates a payment session ("tracker"). Returns the tracker token.
  static Future<String> createSession({
    required double amount,
    required String orderId,
  }) async {
    final json = await _post('/order/payments/v3/', {
      'merchant_api_key': _merchantApiKey,
      'intent': 'CYBERSOURCE',
      'mode': 'payment',
      'currency': 'PKR',
      'amount': (amount * 100).round(),
      'entry_mode': 'raw',
      'metadata': {'order_id': orderId},
    });
    final data = json['data'] as Map<String, dynamic>?;
    final tracker = data?['tracker'] as Map<String, dynamic>?;
    final token = (tracker?['token'] ?? data?['token']) as String?;
    if (token == null) {
      throw Exception('Safepay createSession: no tracker token in response');
    }
    return token;
  }

  /// Short-lived (1hr) client auth token required to build the checkout URL.
  static Future<String> getPassportToken() async {
    final json = await _post('/client/passport/v1/token', {});
    final token = (json['data'] ?? json['token']) as String?;
    if (token == null) {
      throw Exception('Safepay getPassportToken: no token in response');
    }
    return token;
  }

  /// Builds the hosted checkout URL.
  static String buildCheckoutUrl({
    required String tracker,
    required String tbt,
    required String orderId,
    required String redirectUrl,
    required String cancelUrl,
  }) {
    final base = _checkoutHosts[_env]!;
    final query = {
      'environment': _env,
      'tracker': tracker,
      'tbt': tbt,
      'source': 'mobile',
      'order_id': orderId,
      'redirect_url': redirectUrl,
      'cancel_url': cancelUrl,
    };
    final uri = Uri.parse(base).replace(queryParameters: query);
    return uri.toString();
  }

  /// Fetches the current status of a tracker. Returns the response's
  /// `tracker.state` (e.g. 'TRACKER_ENDED', 'TRACKER_CANCELLED') plus the
  /// raw body for auditing.
  static Future<(String state, Map<String, dynamic> raw)> fetchStatus(
      String tracker) async {
    final res = await http.get(
      Uri.parse('${_hosts[_env]}/reporter/api/v1/payments/$tracker'),
      headers: {
        'Accept': 'application/json',
        'x-sfpy-merchant-secret': _secretKey,
      },
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception('Safepay API error (${res.statusCode}): ${res.body}');
    }
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    final trackerObj = (data['tracker'] ?? data) as Map<String, dynamic>;
    final state = (trackerObj['state'] ?? '').toString();
    return (state, json);
  }
}
