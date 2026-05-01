import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static final StreamController<String> onNotificationTap =
      StreamController<String>.broadcast();

  static const _channelId = 'vaastu_high';
  static const _channelName = 'Vaastu PMC Alerts';

  static Future<void> init() async {
    // ── Request FCM permission ────────────────────────────────
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // ── Android channel ───────────────────────────────────────
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'DPR approvals, snags, billing alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // ── Local notifications init ──────────────────────────────
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, // already requested via FCM
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        final route = details.payload ?? '/dashboard';
        onNotificationTap.add(route);
      },
    );

    // ── Foreground messages ───────────────────────────────────
    FirebaseMessaging.onMessage.listen(showLocalNotification);

    // ── Background tap ─────────────────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      onNotificationTap.add(msg.data['route'] as String? ?? '/dashboard');
    });

    // ── Terminated state tap ──────────────────────────────────
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      onNotificationTap.add(initial.data['route'] as String? ?? '/dashboard');
    }

    // ── Keep token fresh ──────────────────────────────────────
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // Will be synced next time the WebView loads
    });
  }

  static Future<void> showLocalNotification(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    final route = msg.data['route'] as String? ?? '/dashboard';

    await _local.show(
      msg.hashCode,
      n.title ?? 'Vaastu PMC',
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFF97316),
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  static Future<String?> getToken() => FirebaseMessaging.instance.getToken();
}
