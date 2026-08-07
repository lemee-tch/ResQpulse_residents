import 'package:flutter/material.dart';
import 'push_notification.dart';
import 'auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initializes Firebase + foreground listener.
  // Does NOT register device token — nobody is logged in yet.
  await initializeFirebaseMessaging();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQPulse',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A8F)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}
