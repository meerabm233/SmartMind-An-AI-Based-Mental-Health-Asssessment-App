import 'package:flutter/material.dart';

import 'chatbot_screen.dart';
import 'home_dashboard_screen.dart';
import 'profile_screen.dart';
import 'progress_history_screen.dart';
import '../call/incoming_call_dialog.dart';
import '../doctor/doctors_list_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int currentIndex = 0;
  final _progressKey = GlobalKey<ProgressHistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeDashboardScreen(),
      ProgressHistoryScreen(key: _progressKey),
      const DoctorsListScreen(),
      const ChatbotScreen(),
      const ProfileScreen(),
    ];

    return IncomingCallListener(
      child: Scaffold(
        body: IndexedStack(index: currentIndex, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            setState(() => currentIndex = index);
            // The Progress tab is kept alive inside the IndexedStack, so its
            // data only loads once. Refresh it on every visit so newly-saved
            // assessments/headaches show up without a manual pull-to-refresh.
            if (index == 1) _progressKey.currentState?.reload();
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              label: 'Progress',
            ),
            NavigationDestination(
                icon: Icon(Icons.local_hospital_outlined), label: 'Doctors'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
