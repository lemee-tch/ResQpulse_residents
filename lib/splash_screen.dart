import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_wrapper.dart';

/// First screen shown on app launch. Displays the ResQPulse splash image
/// full-screen, then hands off to AuthWrapper, which decides whether to
/// send the person to Home (logged in) or Login (logged out).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset('assets/Splash.png', fit: BoxFit.cover),
      ),
    );
  }
}
