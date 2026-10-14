import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'SmartMind Privacy Policy',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Last updated: April 26, 2026',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          SizedBox(height: 20),
          _Section(
            title: '1. Information We Collect',
            body:
                'We collect information that you provide directly to us, such as when you create an account, '
                'complete mental health assessments, or interact with AI chat support. This includes:\n\n'
                '• Name and email address\n'
                '• Assessment responses (stress, anxiety, depression scores)\n'
                '• Mood entries and chat conversations\n'
                '• Device information and usage analytics',
          ),
          _Section(
            title: '2. How We Use Your Information',
            body:
                'We use the information we collect to:\n\n'
                '• Provide, maintain, and improve the SmartMind app\n'
                '• Personalize your experience and provide AI-driven recommendations\n'
                '• Send you notifications and reminders you have opted in to\n'
                '• Analyze usage trends to enhance features\n'
                '• Comply with legal obligations',
          ),
          _Section(
            title: '3. Data Security',
            body:
                'We implement industry-standard security measures including encryption at rest and in transit '
                'to protect your personal and mental health data. However, no method of transmission over '
                'the internet is 100% secure. We encourage you to use a strong password and keep your '
                'login credentials confidential.',
          ),
          _Section(
            title: '4. Data Sharing',
            body:
                'We do not sell, rent, or trade your personal information to third parties. '
                'We may share anonymized, aggregated data for research purposes. '
                'We may disclose data if required by law or to protect the rights and safety of users.',
          ),
          _Section(
            title: '5. Mental Health Data',
            body:
                'Your mental health assessment results, mood entries, and chat conversations are '
                'treated with the highest level of confidentiality. This data is stored securely '
                'and is only accessible to you. We do not share identifiable mental health data '
                'with any third party, including employers or insurance providers.',
          ),
          _Section(
            title: '6. Your Rights',
            body:
                'You have the right to:\n\n'
                '• Access and review your personal data\n'
                '• Request correction of inaccurate data\n'
                '• Request deletion of your account and data\n'
                '• Opt out of non-essential communications\n'
                '• Export your data in a portable format',
          ),
          _Section(
            title: '7. Cookies & Analytics',
            body:
                'We may use anonymized analytics tools to understand how users interact with '
                'the app. No personally identifiable information is shared with analytics providers.',
          ),
          _Section(
            title: '8. Changes to This Policy',
            body:
                'We may update this Privacy Policy from time to time. We will notify you of '
                'any significant changes through the app or by email. Continued use of SmartMind '
                'after changes constitutes acceptance of the updated policy.',
          ),
          _Section(
            title: '9. Contact Us',
            body:
                'If you have questions or concerns about this Privacy Policy or your data, '
                'please contact us at:\n\n'
                'Email: privacy@smartmind.app\n'
                'Address: SmartMind Technologies, Lahore, Pakistan',
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.6, fontSize: 14)),
        ],
      ),
    );
  }
}
