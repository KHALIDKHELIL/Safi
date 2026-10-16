import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

final notificationProvider = Provider((ref) => NotificationController());

class NotificationController {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  NotificationController() {
    _init();
  }

  Future<void> _init() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit, iOS: DarwinInitializationSettings());
    await _plugin.initialize(settings: initSettings);
  }

// FIXED: Added loanId to track the specific alarm
  Future<void> scheduleReminder(String title, String body, {required DateTime scheduledDate, required String loanId}) async {
    if (!kIsWeb) {
      // Creates a safe, trackable integer ID from the loan's database ID
      final int notificationId = loanId.hashCode.remainder(100000).abs();

      const details = NotificationDetails(
        android: AndroidNotificationDetails('safi', 'Alarms', importance: Importance.max, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        id: notificationId, // FIXED: Uses the trackable ID
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } else {
      debugPrint('⚠️ Web Browser Detected: Skipped local OS alarm.');
    }

    _sendTelegramAlert('🔔 *Safi Reminder Scheduled*\n\n$title\n$body\n\nDue: ${scheduledDate.toString().substring(0, 16)}');
  }

  // NEW: This finds the exact alarm by its loan ID and deletes it from the OS
  Future<void> cancelReminder(String loanId) async {
    if (!kIsWeb) {
      final int notificationId = loanId.hashCode.remainder(100000).abs();
      await _plugin.cancel(id:notificationId);
      debugPrint('✅ Cancelled local OS alarm for settled loan.');
    }
  }

Future<void> _sendTelegramAlert(String message) async {
    final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];
    final chatId = dotenv.env['TELEGRAM_CHAT_ID'];
    
    // 1. Check if the .env file is actually loading
    if (botToken == null || chatId == null) {
      debugPrint('⚠️ TELEGRAM ERROR: .env variables are missing! Token: $botToken, ChatID: $chatId');
      return; 
    }
    
    debugPrint('🚀 Sending Telegram message to ID: $chatId...');
    
    final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');
    try {
      final response = await http.post(url, body: {
        'chat_id': chatId,
        'text': message,
      });
      
      // 2. Expose the exact API rejection reason
      if (response.statusCode != 200) {
        debugPrint('❌ Telegram API Rejected [${response.statusCode}]: ${response.body}');
      } else {
        debugPrint('✅ Telegram message sent successfully!');
      }
    } catch (e) {
      // 3. Catch missing Android Internet permissions
      debugPrint('❌ Network/Connection Error: $e');
    }
  }
}