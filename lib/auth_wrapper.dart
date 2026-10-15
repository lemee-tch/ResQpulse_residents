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
      // this citizen so broadcasts can actually reach their device. It
      // runs in the background, so Home opens right away.
      await registerFcmToken();
      _goTo(const HomeScreen());
      // Opened by tapping a notification: show its report or alert.
      openPendingNotification();
      return;
    }

    // The server rejected the login (an admin removed the account):
    // getMe() already cleared it and opened Home in guest mode.
    if (result.statusCode == 401) return;

    // No internet, or the server had a problem: stay logged in with the
    // saved profile, so the resident keeps their account — and an SOS
    // still goes out as theirs. Home checks again on pull-to-refresh.
    // Before, this dropped them into guest mode.
    final saved = await ApiService.getUser();
    if (!mounted) return;

    if (saved != null) {
      await registerFcmToken();
      _goTo(const HomeScreen());
      openPendingNotification();
    } else {
      await ApiService.clearSession();
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

  /// The old start-up badge: now only shown if the logo can't load.
  Widget _rqBadge() {
    return Container(
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
            // The ResQPulse logo, same as on Login — the app used to start
            // on a plain "RQ" circle.
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A3A8F).withOpacity(0.22),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _rqBadge(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ResQPulse',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 28),
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
