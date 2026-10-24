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
  static const _channelName = 'v connect Alerts';

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
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint("====================");
      debugPrint("ON MESSAGE");
      debugPrint("Title: ${msg.notification?.title ?? msg.data['title']}");
      debugPrint("Body: ${msg.notification?.body ?? msg.data['body']}");
      debugPrint("Data: ${msg.data}");
      debugPrint("====================");
      showLocalNotification(msg);
    });

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
      debugPrint("[FCM] Token refreshed: $newToken");
    });
  }

  static Future<void> showLocalNotification(RemoteMessage msg) async {
    final n = msg.notification;
    final data = msg.data;

    // Support both notification object and data-only payloads
    final String title = n?.title ?? data['title'] ?? 'v connect';
    final String? body = n?.body ?? data['body'];
    final String route = data['route'] as String? ?? '/dashboard';

    // If both notification and body in data are missing, nothing to show
    if (n == null && body == null) {
      debugPrint("[FCM] Received message with no displayable content.");
      return;
    }

    debugPrint("====================");
    debugPrint("SHOW LOCAL NOTIFICATION");
    debugPrint("Title: $title");
    debugPrint("Body: $body");
    debugPrint("====================");

    await _local.show(
      msg.hashCode,
      title,
      body,
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

  static Future<String?> getToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      debugPrint("[FCM] Token generated: $token");
    }
    return token;
  }
}
