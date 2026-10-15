import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'alert.dart';
import 'my_reports.dart';

/// Lets push_service show a SnackBar without needing a BuildContext
/// passed down from whatever widget happens to be on screen.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Local notifications plugin — this is what actually draws a system
/// notification banner (like a real push), instead of an in-app SnackBar.
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Also the channel notifications use while the app is closed — see the
/// default_notification_channel_id in AndroidManifest.xml.
const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'alerts_channel', // must match the id used in .show() below
  'Alerts',
  description: 'Emergency and broadcast alerts from MDRRMO Rosales',
  importance: Importance.high,
);

/// Whether Firebase started. When it can't (no Google Play services on the
/// phone, no internet on the very first launch, a bad google-services.json)
/// the app still opens and works — just without push notifications.
/// Before, a Firebase error at start stopped the app from opening.
bool _firebaseReady = false;

/// Whether push notifications can work on this phone (Firebase started).
bool get pushAvailable => _firebaseReady;

// ── Where a tapped notification leads ─────────────────────────────────
//
// 'reports' → My Reports, for updates on the resident's own report or SOS
// (Report Approved / Report Declined / Incident Resolved). 'alerts' →
// Alerts, for MDRRMO's broadcasts. Before, a tap only opened the app.

/// The notification that launched the app while it was closed. Opened by
/// AuthWrapper once Home is showing (openPendingNotification()).
String? _pendingTarget;

String _targetFor(String? type, String? title) {
  if (type == 'report' || type == 'incident' || type == 'sos') return 'reports';
  if (type == 'alert') return 'alerts';

  // The server doesn't send a type yet, so go by the title: these three
  // are the only notifications about a resident's own report.
  const reportTitles = {
    'Report Approved',
    'Report Declined',
    'Incident Resolved',
  };
  return reportTitles.contains(title?.trim()) ? 'reports' : 'alerts';
}

String _targetForMessage(RemoteMessage message) =>
    _targetFor(message.data['type']?.toString(), message.notification?.title);

/// Opens My Reports or Alerts for a tapped notification — only for a
/// logged-in, verified resident, since those are the screens Home unlocks
/// after verification. Anyone else just stays where the app opened.
Future<void> openNotificationTarget(String? target) async {
  if (target != 'reports' && target != 'alerts') return;
  if (!await ApiService.isLoggedIn()) return;

  final user = await ApiService.getUser();
  if (user?['verification_status']?.toString() != 'verified') return;

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  navigator.push(
    MaterialPageRoute(
      builder: (_) =>
          target == 'reports' ? const MyReportsScreen() : const AlertsScreen(),
    ),
  );
}

/// Called by AuthWrapper once Home is open: opens the screen for the
/// notification that launched the app, if there was one.
Future<void> openPendingNotification() async {
  final target = _pendingTarget;
  _pendingTarget = null;
  await openNotificationTarget(target);
}

/// Call ONCE, at cold app start (in main(), before runApp()).
/// Sets up Firebase itself, local notifications, and the foreground-message
/// listener. Does NOT register a device token — nobody is logged in yet.
/// Never throws.
Future<void> initializeFirebaseMessaging() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    _firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase could not start — no push notifications: $e');
    return;
  }

  try {
    // --- Local notifications setup ---
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    // A tap on a banner shown while the app was open.
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        openNotificationTarget(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_alertsChannel);

    // The app was closed and was opened by tapping one of those banners.
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingTarget = launch!.notificationResponse?.payload;
    }
  } catch (e) {
    debugPrint('Local notifications could not start: $e');
  }

  // While the app is open (foreground), Android does NOT auto-show a
  // system notification for "notification"-type FCM messages — this
  // listener is what surfaces the alert to the person in that case.
  // When the app is backgrounded or fully closed, the system tray
  // notification appears automatically (on the Alerts channel, see
  // AndroidManifest.xml).
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null) return;
    final target = _targetForMessage(message);

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
      payload: target,
    );

    // Also an in-app SnackBar for residents already looking at the
    // screen, with View to open the report or the alerts.
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body != null ? '$title — $body' : title),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => openNotificationTarget(target),
          ),
        ),
      );
    }
  });

  // A notification tapped while the app was in the background.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    openNotificationTarget(_targetForMessage(message));
  });

  // A notification tapped while the app was closed — opened once Home
  // shows (AuthWrapper calls openPendingNotification()).
  try {
    final initial = await FirebaseMessaging.instance
        .getInitialMessage()
        .timeout(const Duration(seconds: 5));
    if (initial != null) _pendingTarget = _targetForMessage(initial);
  } catch (e) {
    debugPrint('Could not read the notification that opened the app: $e');
  }

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
///
/// Returns right away: the token is sent in the background, so opening
/// Home never waits on Firebase. Before, login and app start waited for
/// the token and could stay on the loading circle when Firebase couldn't
/// give one (no internet, no Google Play services). Never throws.
Future<void> registerFcmToken() async {
  unawaited(_sendFcmToken());
}

Future<void> _sendFcmToken() async {
  if (!_firebaseReady) return;
  try {
    final messaging = FirebaseMessaging.instance;
    // Android 13+ asks the resident to allow notifications.
    await messaging.requestPermission();

    final token = await messaging.getToken().timeout(
      const Duration(seconds: 20),
    );
    debugPrint('FCM getToken() returned: $token');
    if (token != null) {
      await ApiService.updateFcmToken(token);
    }
  } catch (e) {
    debugPrint('FCM token not registered: $e');
  }
}

/// On logout (and when the server ends the session): deletes this phone's
/// notification token. The resident who logged out stops getting their
/// notifications on this phone, and whoever logs in next gets a new token
/// of their own. Before, the old token stayed on the server, so a logged-out
/// phone — even with someone else logged in — kept getting the previous
/// resident's notifications. Never throws.
Future<void> unregisterFcmToken() async {
  if (!_firebaseReady) return;
  try {
    await FirebaseMessaging.instance.deleteToken().timeout(
      const Duration(seconds: 10),
    );
  } catch (e) {
    debugPrint('FCM token not deleted: $e');
  }
}

// ── For Profile → Notification Settings ───────────────────────────────

/// true = notifications are allowed for ResQPulse, false = turned off,
/// null = not decided yet or unknown (push not available on this phone).
Future<bool?> notificationsAllowed() async {
  if (!_firebaseReady) return null;
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      AuthorizationStatus.denied => false,
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// Asks the resident to allow notifications (Android 13+ shows its own
/// prompt) and, when they do, makes sure the server has this phone's
/// token. Returns whether notifications are allowed now. When the phone
/// won't ask again, the caller opens the phone's settings instead.
Future<bool> askNotificationPermission() async {
  if (!_firebaseReady) return false;
  try {
    final settings = await FirebaseMessaging.instance.requestPermission();
    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (allowed) unawaited(_sendFcmToken());
    return allowed;
  } catch (_) {
    return false;
  }
}

/// Shows a sample notification on the Alerts channel, so the resident can
/// see that notifications work on this phone. Returns false if it couldn't.
Future<bool> showTestNotification() async {
  try {
    await _localNotifications.show(
      7, // a fixed id: tapping "Send a test" again replaces it
      'ResQPulse',
      'Notifications are working. Alerts from MDRRMO Rosales will look like this.',
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
    return true;
  } catch (_) {
    return false;
  }
}
