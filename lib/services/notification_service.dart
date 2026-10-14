import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Stable notification ids for the reminders configurable in
/// NotificationSettingsScreen — scheduling the same id again replaces the
/// existing alarm instead of stacking a duplicate.
class ReminderIds {
  static const int dailyReminder = 1;
  static const int assessmentReminder = 2;
}

/// Thin wrapper around flutter_local_notifications for scheduling the
/// repeating local reminders configured in NotificationSettingsScreen.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'smartmind_reminders',
    'Reminders',
    channelDescription: 'Daily check-in and assessment reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (e) {
      debugPrint('NotificationService: could not resolve local timezone: $e');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Requests OS notification permission (Android 13+ POST_NOTIFICATIONS,
  /// iOS alert/badge/sound). Returns whether it's granted; platforms with
  /// no such prompt (desktop/web) are treated as already granted.
  static Future<bool> requestPermission() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  /// Schedules a notification that repeats daily at [time] in the device's
  /// local time zone, replacing any previously scheduled reminder with the
  /// same [id].
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOf(time),
      notificationDetails: const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact timing is fine for a wellness reminder and avoids needing
      // Android 12+'s special "exact alarm" permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }

  /// Requests notification permission at most once, the first time this
  /// runs (tracked via SharedPreferences) — so a user who never visits
  /// Notification Settings still gets asked, since reminders default to
  /// on and silently never showing anything without this is not obvious.
  /// Never re-prompts on later launches even if the user declined.
  static Future<void> requestPermissionIfNeededOnce(
      SharedPreferences prefs) async {
    if (prefs.getBool('notif_permission_requested') ?? false) return;
    await requestPermission();
    await prefs.setBool('notif_permission_requested', true);
  }

  /// Re-applies whatever reminder schedule the user last saved in
  /// NotificationSettingsScreen. Android clears scheduled alarms on device
  /// reboot, so this is called on every app startup to restore them —
  /// intentionally does NOT prompt for permission (that only happens when
  /// the user actively saves settings), so a not-yet-granted permission
  /// just means these calls are silently no-ops until they do.
  static Future<void> restoreFromSavedPreferences(
      SharedPreferences prefs) async {
    if (prefs.getBool('notif_daily_reminder') ?? true) {
      await scheduleDaily(
        id: ReminderIds.dailyReminder,
        title: 'Daily Check-in',
        body: "It's time for your daily mental health check-in.",
        time: TimeOfDay(
          hour: prefs.getInt('notif_reminder_hour') ?? 9,
          minute: prefs.getInt('notif_reminder_minute') ?? 0,
        ),
      );
    }
    if (prefs.getBool('notif_assessment_reminder') ?? true) {
      await scheduleDaily(
        id: ReminderIds.assessmentReminder,
        title: 'Assessment Reminder',
        body: 'Take a moment to complete your DASS-21 assessment.',
        time: TimeOfDay(
          hour: prefs.getInt('notif_assessment_hour') ?? 10,
          minute: prefs.getInt('notif_assessment_minute') ?? 0,
        ),
      );
    }
  }

  static tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
