import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'legal.dart';
import 'phone_call.dart';

/// The version shown on this screen. Keep it the same as `version:` in
/// pubspec.yaml (the part before the "+").
const String kAppVersion = '0.1.0';

const String _mdrrmoNumber = '#2441';

/// Profile → About ResQPulse.
///
/// Item 64: what the app is (and isn't), who runs it, a summary of what
/// happens to the resident's information, and the Privacy Policy, Terms
/// and Conditions, Cookie Policy and Accessibility pages. The "Developed
/// by" list was removed; what the app promises was checked so it doesn't
/// promise more than it can (no "real-time", no "one tap").
///
/// Accessibility: section titles are headings for screen readers, rows
/// are read as one item, buttons are at least 48 dp tall, text follows the
/// phone's font size, and every text color has at least 4.5:1 contrast.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _red = Color(0xFFC62828);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF4B5563);

  Future<void> _callMdrrmo(BuildContext context) async {
    final opened = await openDialer(_mdrrmoNumber);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t open the phone app. Dial #2441 to reach MDRRMO Rosales.',
          ),
          backgroundColor: _red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About ResQPulse',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _header(),
            const SizedBox(height: 24),
            _emergencyCard(context),
            const SizedBox(height: 16),
            _card(
              title: 'What you can do',
              children: const [
                _InfoRow(
                  icon: Icons.sos,
                  color: _red,
                  title: 'Send an SOS',
                  text:
                      'Choose the kind of emergency and send MDRRMO your '
                      'location, with a photo if you take one. You can send '
                      'one without an account.',
                ),
                _InfoRow(
                  icon: Icons.warning_amber_rounded,
                  color: Color(0xFFB45309),
                  title: 'Report an emergency',
                  text:
                      'Fires, floods, accidents and other incidents, with '
                      'photos and where it happened.',
                ),
                _InfoRow(
                  icon: Icons.campaign,
                  color: _navy,
                  title: 'Get disaster alerts',
                  text:
                      'Warnings and announcements from MDRRMO Rosales, when '
                      'notifications are on.',
                ),
                _InfoRow(
                  icon: Icons.description,
                  color: Color(0xFF1565C0),
                  title: 'Follow your reports',
                  text:
                      'See when MDRRMO reviews your report, when responders '
                      'are sent, and when it\'s resolved.',
                ),
                _InfoRow(
                  icon: Icons.phone_in_talk,
                  color: Color(0xFF00796B),
                  title: 'Hotlines, evacuation centers and safety tips',
                  text: 'Open to everyone, even without an account.',
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Good to know',
              children: const [
                _InfoRow(
                  icon: Icons.wifi_off_rounded,
                  color: Color(0xFFB45309),
                  title: 'It needs internet and location',
                  text:
                      'ResQPulse can\'t send anything without a connection, '
                      'and GPS can be off by several meters indoors. If an '
                      'SOS doesn\'t go through, call #2441 or 911.',
                ),
                _InfoRow(
                  icon: Icons.notifications_paused_outlined,
                  color: _navy,
                  title: 'Alerts can be late',
                  text:
                      'A notification can be delayed or missed when your phone '
                      'is offline or notifications are off. Follow official '
                      'announcements too.',
                ),
                _InfoRow(
                  icon: Icons.report_gmailerrorred_rounded,
                  color: _red,
                  title: 'False reports',
                  text:
                      'Sending a false or prank SOS or report can get your '
                      'account blocked, and may be reported to the '
                      'authorities.',
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Your information',
              children: [
                const _InfoRow(
                  icon: Icons.badge,
                  color: _navy,
                  title: 'Your account',
                  text:
                      'MDRRMO uses your name, address, contact details and the '
                      'photo of your ID to confirm that you live in Rosales.',
                ),
                const _InfoRow(
                  icon: Icons.location_on,
                  color: _red,
                  title: 'Your location',
                  text:
                      'Sent to MDRRMO only when you send an SOS or a report, '
                      'so responders can find you.',
                ),
                const _InfoRow(
                  icon: Icons.shield_outlined,
                  color: Color(0xFF2E7D32),
                  title: 'Who sees your report',
                  text:
                      'MDRRMO Rosales and the responders sent to help. '
                      'MDRRMO doesn\'t sell your information or use it for ads.',
                ),
                const _InfoRow(
                  icon: Icons.manage_accounts_outlined,
                  color: Color(0xFF6D28D9),
                  title: 'Your rights',
                  text:
                      'You can ask MDRRMO to see, correct or delete your '
                      'information. Call #2441 or visit the MDRRMO office.',
                  last: true,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        openLegal(context, LegalDoc.privacy, accent: _navy),
                    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: const Text('Read the Privacy Policy'),
                    style: TextButton.styleFrom(
                      foregroundColor: _navy,
                      minimumSize: const Size(48, 48),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Legal',
              children: const [LegalLinks(accent: _navy)],
            ),
            const SizedBox(height: 20),
            const Text(
              'ResQPulse is run by the Municipal Disaster Risk Reduction and '
              'Management Office (MDRRMO) of Rosales, Pangasinan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.22),
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
              semanticLabel: 'ResQPulse logo',
              errorBuilder: (context, error, stackTrace) => Container(
                color: _navy,
                alignment: Alignment.center,
                child: const Text(
                  'RQ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: const Text(
            'ResQPulse',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Version $kAppVersion',
          style: TextStyle(fontSize: 13.5, color: _muted),
        ),
        const SizedBox(height: 10),
        const Text(
          'Send an SOS, report emergencies and get disaster alerts from '
          'MDRRMO Rosales, Pangasinan.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF374151),
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _emergencyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _red,
                  child: Icon(
                    Icons.phone_in_talk,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    'In an emergency',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8E1B1B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Call MDRRMO Rosales at #2441 or 911, or press SOS on Home. '
            'ResQPulse helps you reach MDRRMO, but it doesn\'t replace '
            'calling for help.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF7F1D1D),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _callMdrrmo(context),
              icon: const Icon(Icons.call, size: 20),
              label: const Text(
                'Call MDRRMO Rosales',
                semanticsLabel: 'Call MDRRMO Rosales at #2441',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// An icon, a title and a sentence — read as one item by screen readers.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final bool last;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF4B5563),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
