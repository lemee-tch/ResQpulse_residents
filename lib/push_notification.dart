import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Lets push_service show a SnackBar without needing a BuildContext
/// passed down from whatever widget happens to be on screen.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Local notifications plugin — this is what actually draws a system
/// notification banner (like a real push), instead of an in-app SnackBar.
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'alerts_channel', // must match the id used in .show() below
  'Alerts',
  description: 'Emergency and broadcast alerts from MDRRMO Rosales',
  importance: Importance.high,
);

/// Call ONCE, at cold app start (in main(), before runApp()).
/// Sets up Firebase itself, local notifications, and the foreground-message
/// listener. Does NOT register a device token — nobody is logged in yet.
Future<void> initializeFirebaseMessaging() async {
  await Firebase.initializeApp();

  // --- Local notifications setup ---
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );

  await _localNotifications.initialize(initSettings);

  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_alertsChannel);

  // While the app is open (foreground), Android does NOT auto-show a
  // system notification for "notification"-type FCM messages — this
  // listener is what surfaces the alert to the person in that case.
  // When the app is backgrounded or fully closed, the system tray
  // notification appears automatically; no extra code needed for that.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null) return;

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertsChannel.id,
          _alertsChannel.name,
          channelDescription: _alertsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFC62828),
        ),
      ),
    );

    // Optional: still show the in-app SnackBar too, for users already
    // looking at the screen when it arrives. Comment out if you only
    // want the system banner.
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body != null ? '$title — $body' : title),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  });

  // Token can rotate at any time — keep the backend updated whenever it
  // does. This listener is safe to attach even before login: if nobody's
  // authenticated yet when it fires, ApiService.updateFcmToken() just
  // fails silently (non-critical), same as any other call made too early.
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    ApiService.updateFcmToken(newToken);
  });
}

/// Call this AFTER a successful login, AFTER a successful registration,
/// and AFTER AuthWrapper confirms an existing valid session on cold start.
/// This is what actually attaches a device token to the now-authenticated
/// citizen — calling it before login has no one to attach the token to.
Future<void> registerFcmToken() async {
  debugPrint('registerFcmToken() called');
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  final token = await messaging.getToken();
  debugPrint('FCM getToken() returned: $token');
  if (token != null) {
    await ApiService.updateFcmToken(token);
  }
}
