import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'phone_call.dart';

/// The version shown on this screen. Keep it the same as `version:` in
/// pubspec.yaml (the part before the "+").
const String kAppVersion = '0.1.0';

/// The team listed under "Developed by". Edit the names and roles here.
const List<_Member> _researchers = [
  _Member('Frederick N. Manganaan', 'Team Leader'),
  _Member('Lemuel R. Consolacion', 'Programmer'),
  _Member('Dwayne E. Ventura'),
  _Member('John Paul L. Dalugdog'),
  _Member('Lorenzo P. Rubenecia'),
  _Member('Sean Russel O. Sablan'),
];
const String _adviser = 'Jasmin C. De Guzman, LPT, MIT';

const String _mdrrmoNumber = '#2441';

/// Profile → About ResQPulse (it used to do nothing when tapped).
///
/// What the app is for, what a resident can do with it, how to reach
/// MDRRMO in an emergency, what happens to their information, and who
/// made it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _ink = Color(0xFF1A1A2E);

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
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
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
      body: ListView(
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
                    'One tap sends MDRRMO your location, with a photo if '
                    'you take one. Works even without an account.',
              ),
              _InfoRow(
                icon: Icons.warning_amber_rounded,
                color: Color(0xFFE65100),
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
                    'Warnings and announcements from MDRRMO Rosales, '
                    'right on your phone.',
              ),
              _InfoRow(
                icon: Icons.description,
                color: Color(0xFF1565C0),
                title: 'Follow your reports',
                text:
                    'See when MDRRMO reviews your report, who is '
                    'responding, and when it\'s resolved.',
              ),
              _InfoRow(
                icon: Icons.phone_in_talk,
                color: Color(0xFF00897B),
                title: 'Hotlines, evacuation centers and first aid',
                text: 'Open to everyone, even without an account.',
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Your information',
            children: const [
              _InfoRow(
                icon: Icons.badge,
                color: _navy,
                title: 'Your account',
                text:
                    'Your name, mobile number, email, address and the '
                    'photo of your ID are used by MDRRMO to check that '
                    'you\'re a resident of Rosales.',
              ),
              _InfoRow(
                icon: Icons.location_on,
                color: _red,
                title: 'Your location',
                text:
                    'Sent to MDRRMO only when you send an SOS or a '
                    'report, so responders can find you.',
              ),
              _InfoRow(
                icon: Icons.shield_outlined,
                color: Color(0xFF2E7D32),
                title: 'Who sees your report',
                text: 'MDRRMO Rosales and the responders sent to help you.',
              ),
              _InfoRow(
                icon: Icons.logout,
                color: Color(0xFF6B7280),
                title: 'Logging out',
                text:
                    'Removes your account from this phone, and the phone '
                    'stops getting your notifications.',
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _creditsCard(),
          const SizedBox(height: 20),
          Text(
            'Made for the people of Rosales, Pangasinan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
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
        const Text(
          'ResQPulse',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Version $kAppVersion',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),
        Text(
          'Emergency reporting and real-time disaster alerts for MDRRMO '
          'Rosales, Pangasinan.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.45),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In an emergency',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Call MDRRMO Rosales at #2441, or press SOS on Home.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF7F1D1D),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _callMdrrmo(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Call',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _creditsCard() {
    return _card(
      title: 'Developed by',
      children: [
        Text(
          'A capstone project of the College of Information and Technology '
          'Education, Urdaneta City University, for MDRRMO Rosales.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        ..._researchers.map(
          (member) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.person, size: 18, color: _navy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
                if (member.role.isNotEmpty)
                  Text(
                    member.role,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 20),
        Row(
          children: [
            const Icon(Icons.school, size: 18, color: _navy),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                _adviser,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
            Text(
              'Adviser',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ],
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Member {
  final String name;
  final String role;
  const _Member(this.name, [this.role = '']);
}

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
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
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
      ),
    );
  }
}
