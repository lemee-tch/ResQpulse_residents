import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'push_notification.dart';

/// Profile → Notification Settings (it used to do nothing when tapped).
///
/// Shows whether notifications are allowed for ResQPulse on this phone,
/// turns them on (Android's own prompt, or the phone's settings when it
/// won't ask again), says what the resident gets, and sends a test
/// notification so they can see it works. The status is checked again
/// when they come back from the phone's settings.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFD32F2F);

  bool _loading = true;
  bool _busy = false;

  /// true = on, false = off, null = not decided yet / unknown.
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings — they may have changed it there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final allowed = await notificationsAllowed();
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _loading = false;
    });
  }

  Future<void> _turnOn() async {
    setState(() => _busy = true);
    final allowed = await askNotificationPermission();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _allowed = allowed ? true : _allowed;
    });
    if (allowed) {
      _snack('Notifications are on.', _green);
      return;
    }
    // The phone won't show its prompt again (the resident said no before):
    // open ResQPulse's page in the phone's settings instead.
    await _openPhoneSettings();
  }

  Future<void> _openPhoneSettings() async {
    final opened = await Geolocator.openAppSettings();
    if (!opened && mounted) {
      _snack(
        'Open your phone\'s Settings → Apps → ResQPulse → Notifications.',
        _navy,
      );
    }
  }

  Future<void> _sendTest() async {
    final shown = await showTestNotification();
    if (!mounted) return;
    _snack(
      shown
          ? 'Test notification sent. Check the top of your screen.'
          : 'The test notification couldn\'t be shown.',
      shown ? _green : _red,
    );
  }

  void _snack(String text, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1A1A2E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _statusCard(),
                const SizedBox(height: 16),
                _whatYouGetCard(),
                if (_allowed == true) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _sendTest,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text(
                        'Send a test notification',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _navy, width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _turnOffNote(),
              ],
            ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statusCard() {
    final bool on = _allowed == true;
    final bool available = pushAvailable;

    final IconData icon = !available
        ? Icons.notifications_off
        : (on ? Icons.notifications_active : Icons.notifications_off);
    final Color color = !available ? Colors.grey : (on ? _green : _red);
    final String title = !available
        ? 'Notifications aren\'t available'
        : (on ? 'Notifications are on' : 'Notifications are off');
    final String text = !available
        ? 'This phone can\'t receive notifications from ResQPulse right now '
              '(it needs Google Play services and an internet connection). '
              'Check Alerts in the app for MDRRMO\'s announcements.'
        : (on
              ? 'You\'ll get MDRRMO\'s alerts and updates on your reports on '
                    'this phone, even when the app is closed.'
              : 'Turn them on so you don\'t miss disaster alerts and updates '
                    'on your reports.');

    return _card(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey[600],
              height: 1.45,
            ),
          ),
          if (available && !on) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _turnOn,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.notifications_active, size: 20),
                label: const Text(
                  'Turn on notifications',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _whatYouGetCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'What you\'ll get',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: 14),
          _InfoRow(
            icon: Icons.campaign,
            color: Color(0xFFD32F2F),
            title: 'Disaster alerts and announcements',
            text:
                'Typhoon and flood warnings, evacuation notices and other '
                'announcements from MDRRMO Rosales.',
          ),
          SizedBox(height: 14),
          _InfoRow(
            icon: Icons.description,
            color: Color(0xFF1A3A8F),
            title: 'Updates on your reports and SOS',
            text:
                'When MDRRMO approves or declines a report, and when it\'s '
                'resolved. Tap one to open My Reports.',
          ),
          SizedBox(height: 14),
          _InfoRow(
            icon: Icons.smartphone,
            color: Color(0xFF2E7D32),
            title: 'Only on this phone, while you\'re logged in',
            text:
                'When you log out, this phone stops getting your '
                'notifications.',
          ),
        ],
      ),
    );
  }

  Widget _turnOffNote() {
    return Column(
      children: [
        Text(
          'To turn notifications off, or change their sound, use your '
          'phone\'s settings for ResQPulse.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey[600],
            height: 1.45,
          ),
        ),
        TextButton.icon(
          onPressed: _openPhoneSettings,
          icon: const Icon(Icons.settings, size: 18),
          label: const Text(
            'Open phone settings',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: TextButton.styleFrom(foregroundColor: _navy),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
