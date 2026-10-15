import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'login.dart';
import 'home.dart';
import 'hotlines.dart';
import 'edit_profile.dart';
import 'notification_settings.dart';
import 'about.dart';

/// Home → Profile.
///
/// A blue header like Home's (initials, name, number and email, and the
/// ID check status), a note while the ID is being checked or wasn't
/// approved, the account menu (each item says what's inside), and Log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _red = Color(0xFFD32F2F);

  Map<String, dynamic>? _citizen;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCitizen();
    _refreshFromServer();
  }

  /// The profile saved on this phone (updated by every screen that
  /// changes it).
  Future<void> _loadCitizen() async {
    final citizen = await ApiService.getUser();
    if (!mounted) return;
    setState(() {
      _citizen = citizen;
      _isLoading = false;
    });
  }

  /// The latest from the server, e.g. MDRRMO approved the ID since.
  Future<void> _refreshFromServer() async {
    final result = await ApiService.getMe();
    if (!mounted || !result.success || result.data is! Map) return;
    setState(() => _citizen = Map<String, dynamic>.from(result.data));
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log out?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You\'ll need your password to log in again. This phone stops '
          'getting your notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleLogout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // No previous screen — go to a safe fallback, e.g. home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  /// Personal Information. The email or number can change there (with a
  /// code) without Save Changes, so the saved profile is read again after.
  Future<void> _openPersonalInformation() async {
    if (_citizen == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(citizen: _citizen!)),
    );
    if (mounted) _loadCitizen();
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String get _name {
    final name = _citizen?['full_name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Resident' : name;
  }

  /// "Lemuel Conso" → "LC".
  String get _initials {
    final first = _citizen?['first_name']?.toString().trim() ?? '';
    final last = _citizen?['last_name']?.toString().trim() ?? '';
    final parts = [first, last].where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      parts.addAll(_name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty));
    }
    if (parts.isEmpty) return '?';
    final letters = parts.length == 1
        ? parts.first[0]
        : '${parts.first[0]}${parts.last[0]}';
    return letters.toUpperCase();
  }

  String get _status =>
      _citizen?['verification_status']?.toString() ?? 'pending';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons over the blue header, like Home.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _header(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_status != 'verified') ...[
                          _statusNote(),
                          const SizedBox(height: 16),
                        ],
                        _menuCard(),
                        const SizedBox(height: 16),
                        _logoutCard(),
                        const SizedBox(height: 20),
                        Text(
                          'ResQPulse · Version $kAppVersion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
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

  // ── Header ──────────────────────────────────────────────────────────

  Widget _header() {
    final mobile = _citizen?['mobile']?.toString().trim() ?? '';
    final email = _citizen?['email']?.toString().trim() ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00308F), Color(0xFF1A5DC8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 26),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _goBack,
                  ),
                  const Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),

              // Initials in a white circle with a soft ring.
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (mobile.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  mobile,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _statusBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge() {
    IconData icon = Icons.hourglass_top_rounded;
    Color color = const Color(0xFFB45309);
    String label = 'Verification Pending';
    if (_status == 'verified') {
      icon = Icons.verified;
      color = const Color(0xFF2E7D32);
      label = 'Verified Resident';
    } else if (_status == 'rejected') {
      icon = Icons.error_outline;
      color = _red;
      label = 'ID Not Approved';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// While the ID is being checked, or when it wasn't approved.
  Widget _statusNote() {
    final rejected = _status == 'rejected';
    final reason = _citizen?['rejection_reason']?.toString().trim() ?? '';

    final Color bg = rejected
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF3C7);
    final Color fg = rejected
        ? const Color(0xFF991B1B)
        : const Color(0xFF92400E);
    final String text = rejected
        ? (reason.isNotEmpty
              ? 'MDRRMO couldn\'t verify your ID: $reason. For help, call '
                    'MDRRMO Rosales at #2441.'
              : 'MDRRMO couldn\'t verify your ID. For help, call MDRRMO '
                    'Rosales at #2441.')
        : 'MDRRMO is checking your ID. Reporting an emergency, Disaster '
              'Alerts and My Reports open once it\'s approved. SOS works now.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? Icons.error_outline : Icons.hourglass_top_rounded,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: fg, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu ────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(color: Colors.white, child: child),
      ),
    );
  }

  Widget _menuCard() {
    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: Colors.grey[100],
    );

    return _card(
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.person_outline,
            color: _navy,
            title: 'Personal Information',
            subtitle: 'Name, address, email and mobile number',
            onTap: _openPersonalInformation,
          ),
          divider,
          _MenuRow(
            icon: Icons.phone_in_talk_outlined,
            color: const Color(0xFF00897B),
            title: 'Emergency Contacts',
            subtitle: 'MDRRMO, police, fire and your barangay',
            onTap: () => _open(const EmergencyHotlinesScreen()),
          ),
          divider,
          _MenuRow(
            icon: Icons.notifications_outlined,
            color: const Color(0xFFF57C00),
            title: 'Notification Settings',
            subtitle: 'Alerts and updates on your reports',
            onTap: () => _open(const NotificationSettingsScreen()),
          ),
          divider,
          _MenuRow(
            icon: Icons.info_outline,
            color: const Color(0xFF6A1B9A),
            title: 'About ResQPulse',
            subtitle: 'The app, your information and the team',
            onTap: () => _open(const AboutScreen()),
          ),
        ],
      ),
    );
  }

  Widget _logoutCard() {
    return _card(
      child: InkWell(
        onTap: _confirmLogout,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout, color: _red, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
          ],
        ),
      ),
    );
  }
}
