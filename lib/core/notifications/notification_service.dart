import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const int _punchInId = 1001;
  static const int _punchOutId = 1002;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit, iOS: DarwinInitializationSettings());
    await _plugin.initialize(initSettings);
    // Timezone init for zoned scheduling (use IST by default)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    // Request permissions on iOS and Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> schedulePunchInReminder(DateTime when, {String title = 'Don’t forget to Punch In', String body = 'Please punch in by 10:15 AM'}) async {
    await init();
    if (when.isBefore(DateTime.now())) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'attendance_reminders',
        'Attendance Reminders',
        channelDescription: 'Reminders for punch in/out',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final whenTz = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      _punchInId,
      title,
      body,
      whenTz,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
    if (kDebugMode) debugPrint('🔔 Scheduled punch-in reminder at $when');
  }

  Future<void> schedulePunchOutReminder(DateTime when, {String title = 'Don’t forget to Punch Out', String body = 'Please punch out by 7:30 PM'}) async {
    await init();
    if (when.isBefore(DateTime.now())) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'attendance_reminders',
        'Attendance Reminders',
        channelDescription: 'Reminders for punch in/out',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final whenTz = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      _punchOutId,
      title,
      body,
      whenTz,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
    if (kDebugMode) debugPrint('🔔 Scheduled punch-out reminder at $when');
  }

  Future<void> cancelPunchInReminder() async {
    await init();
    await _plugin.cancel(_punchInId);
  }

  Future<void> cancelPunchOutReminder() async {
    await init();
    await _plugin.cancel(_punchOutId);
  }
}
