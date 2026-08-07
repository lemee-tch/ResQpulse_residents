import 'package:flutter/material.dart';
import 'api_service.dart';
import 'push_notification.dart';
import 'home.dart';

/// Shown briefly on every app launch. Decides whether to send the
/// person straight to Home (still logged in) or to Login (logged out,
/// or their session/token is no longer valid on the server).
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final hasToken = await ApiService.isLoggedIn();

    if (!hasToken) {
      _goTo(const HomeScreen(isGuest: true));
      return;
    }

    // Token exists locally — confirm it's still valid server-side.
    final result = await ApiService.getMe();

    if (!mounted) return;

    if (result.success) {
      // Session confirmed valid — NOW register the FCM token against
      // this citizen so broadcasts can actually reach their device.
      await registerFcmToken();
      _goTo(const HomeScreen());
    } else {
      _goTo(const HomeScreen(isGuest: true));
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A3A8F), Color(0xFF2E6BE6)],
                ),
              ),
              child: const Center(
                child: Text(
                  'RQ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Color(0xFF1A3A8F),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
