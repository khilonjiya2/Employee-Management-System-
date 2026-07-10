import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _showLocalNotification(message);
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    'attend_pay_channel',
    'EMS Notifications',
    description: 'Employee management notifications',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'EMS',
    message.notification?.body ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(channel.id, channel.name, channelDescription: channel.description, icon: '@mipmap/ic_launcher'),
    ),
  );
}

class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await _requestPermission();
    await _setupLocalNotifications();
    _setupForegroundHandler();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _getAndSaveToken();
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'attend_pay_channel',
      'EMS Notifications',
      importance: Importance.high,
    );

    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((message) async {
      await _showLocalNotification(message);
    });
  }

  Future<void> _getAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': 'android',
      }, onConflict: 'user_id, token');

      _messaging.onTokenRefresh.listen((newToken) async {
        await Supabase.instance.client.from('fcm_tokens').upsert({
          'user_id': user.id,
          'token': newToken,
          'platform': 'android',
        }, onConflict: 'user_id, token');
      });
    } catch (_) {}
  }
}
