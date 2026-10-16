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
    
    // FIXED: Removed 'settings:' (v17 uses positional arguments)
    await _plugin.initialize(initSettings);
  }

  Future<void> scheduleReminder(String title, String body, {required DateTime scheduledDate, required String loanId}) async {
    if (!kIsWeb) {
      final int notificationId = loanId.hashCode.remainder(100000).abs();

      const details = NotificationDetails(
        android: AndroidNotificationDetails('safi', 'Alarms', importance: Importance.max, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      );

      // FIXED: Removed 'id:', 'title:', etc., and added uiLocalNotificationDateInterpretation
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      debugPrint('⚠️ Web Browser Detected: Skipped local OS alarm.');
    }

    _sendTelegramAlert('🔔 *Safi Reminder Scheduled*\n\n$title\n$body\n\nDue: ${scheduledDate.toString().substring(0, 16)}');
  }

  Future<void> cancelReminder(String loanId) async {
    if (!kIsWeb) {
      final int notificationId = loanId.hashCode.remainder(100000).abs();
      
      // FIXED: Removed 'id:' (v17 uses positional arguments)
      await _plugin.cancel(notificationId); 
      
      debugPrint('✅ Cancelled local OS alarm for settled loan.');
    }
  }

  Future<void> _sendTelegramAlert(String message) async {
    final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];
    final chatId = dotenv.env['TELEGRAM_CHAT_ID'];
    
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
      
      if (response.statusCode != 200) {
        debugPrint('❌ Telegram API Rejected [${response.statusCode}]: ${response.body}');
      } else {
        debugPrint('✅ Telegram message sent successfully!');
      }
    } catch (e) {
      debugPrint('❌ Network/Connection Error: $e');
    }
  }
}