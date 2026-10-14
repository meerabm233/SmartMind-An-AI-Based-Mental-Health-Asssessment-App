import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../doctor/doctor_dashboard_screen.dart';
import '../home/main_nav_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () {
      _routeNext();
    });
  }

  Future<void> _routeNext() async {
    try {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Sync any pending assessments saved while user was offline/not logged in
        try {
          await FirestoreService.syncPendingAssessments();
        } catch (_) {}

        final role = await FirestoreService.getCurrentUserRole();
        if (!mounted) return;
        if (role == 'doctor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const DoctorDashboardScreen(),
            ),
          );
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavScreen(),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade300,
              Colors.deepPurple.shade100,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.psychology_alt_outlined,
                  size: 56,
                  color: Colors.deepPurple.shade400,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SmartMind',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Mental Health Companion',
                style: TextStyle(
                  color: Colors.deepPurple.shade300,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}