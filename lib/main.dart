import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter's default error widget shows full details in debug mode but a
  // blank grey screen with NO text in release/profile builds — meaning any
  // widget-build crash anywhere in the app looks exactly like "the screen
  // just doesn't show up," with nothing to diagnose from. Show the actual
  // error message on every build, in every mode, so a crash is always
  // visibly a crash instead of silently blank.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Restore saved theme preference
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('dark_mode') == true) {
      themeModeNotifier.value = ThemeMode.dark;
    }

    // Best-effort: reminders are a nice-to-have, never block app startup on
    // notification plugin setup. Reminders default to on, so most users
    // never visit Notification Settings — request permission here (once
    // ever) rather than only when they happen to open that screen and hit
    // Save, otherwise the default-on reminders silently never show
    // anything. Then re-apply the saved schedule, since Android clears
    // alarms on reboot.
    unawaited(
      NotificationService.init()
          .then((_) => NotificationService.requestPermissionIfNeededOnce(prefs))
          .then((_) => NotificationService.restoreFromSavedPreferences(prefs)),
    );

    runApp(const SmartMindApp());
  } catch (e) {
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 54, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'Startup failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
