import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notificationProvider = Provider((ref) => NotificationController());

class NotificationController {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  NotificationController() {
    _init();
  }

Future<void> _init() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    // Fixed: The required parameter is exactly 'settings'
    await _plugin.initialize(
      settings: initSettings, 
    );
  }
  /// Schedules a native OS push notification
 /// Schedules an alarm for a specific, custom date and time
  Future<void> scheduleReminder(String title, String body, {required DateTime scheduledDate}) async {
    const androidDetails = AndroidNotificationDetails(
      'safi_reminders',
      'Debt Reminders',
      channelDescription: 'Alarms for pending ledgers',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _plugin.zonedSchedule(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000), 
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local), // Uses the exact user-picked time!
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}