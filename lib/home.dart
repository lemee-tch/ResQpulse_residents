import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_incident.dart';
import 'my_reports.dart';
import 'alert.dart';
import 'centers.dart';
import 'profile.dart';
import 'safety_tips.dart';
import 'sos.dart';
import 'hotlines.dart';
import 'api_service.dart';
import 'login.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final GlobalKey<_RecentAlertsCardState> _alertsCardKey = GlobalKey();

  String _citizenName = 'Citizen';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    if (!widget.isGuest) _loadCitizenName();
  }

  String get _displayName => widget.isGuest ? 'Guest' : _citizenName;

  Future<void> _loadCitizenName() async {
    final citizen = await ApiService.getUser();
    if (!mounted) return;
    final fullName = citizen?['full_name'];
    if (fullName != null && fullName.toString().trim().isNotEmpty) {
      setState(() => _citizenName = fullName.toString());
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  // SOS is now available to guests — location (and an optional photo) is
  // all it ever needed. Guest SOS reports are just held for admin review
  // before responders are notified (see ApiService.sendSOS +
  // Api\IncidentController::sos()).
  void _handleSOS() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SOSScreen(isGuest: widget.isGuest)),
    );
  }

  Future<void> _handleRefresh() async {
    if (widget.isGuest) return;
    await Future.wait([
      _alertsCardKey.currentState?.refresh() ?? Future.value(),
      _loadCitizenName(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _HomeTab(
        waveController: _waveController,
        onSOS: _handleSOS,
        onRefresh: _handleRefresh,
        alertsCardKey: _alertsCardKey,
        citizenName: _displayName,
        isGuest: widget.isGuest,
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final AnimationController waveController;
  final VoidCallback onSOS;
  final Future<void> Function() onRefresh;
  final GlobalKey<_RecentAlertsCardState> alertsCardKey;
  final String citizenName;
  final bool isGuest;

  const _HomeTab({
    required this.waveController,
    required this.onSOS,
    required this.onRefresh,
    required this.alertsCardKey,
    required this.citizenName,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        // Blue curved header
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            ClipPath(
              clipper: _BottomCurveClipper(),
              child: Container(
                width: double.infinity,
                height: size.height * 0.42,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF00308F), Color(0xFF1A5DC8)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, $citizenName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isGuest
                                        ? 'Browsing as guest — log in for full access.'
                                        : "Stay safe, we're here to help.",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // ── Profile icon, top-right ──
                            GestureDetector(
                              onTap: () {
                                if (isGuest) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileScreen(),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isGuest ? Icons.login : Icons.person_outline,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
            // SOS glowing button
            Positioned(
              bottom: -10,
              child: GestureDetector(
                onTap: onSOS,
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: AnimatedBuilder(
                    animation: waveController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          _WaveRing(
                            animation: CurvedAnimation(
                              parent: waveController,
                              curve: const Interval(
                                0.0,
                                1.0,
                                curve: Curves.easeOut,
                              ),
                            ),
                            maxRadius: 120,
                            color: Colors.white,
                            maxOpacity: 0.15,
                          ),
                          _WaveRing(
                            animation: CurvedAnimation(
                              parent: waveController,
                              curve: const Interval(
                                0.25,
                                1.0,
                                curve: Curves.easeOut,
                              ),
                            ),
                            maxRadius: 105,
                            color: Colors.white,
                            maxOpacity: 0.22,
                          ),
                          _WaveRing(
                            animation: CurvedAnimation(
                              parent: waveController,
                              curve: const Interval(
                                0.5,
                                1.0,
                                curve: Curves.easeOut,
                              ),
                            ),
                            maxRadius: 88,
                            color: Colors.white,
                            maxOpacity: 0.30,
                          ),
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 6,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00308F),
                                    letterSpacing: 3,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'TAP FOR EMERGENCY',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),

        // Grid + Recent Alerts (pull-to-refresh)
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: const Color(0xFF00308F),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Column(
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    children: [
                      // Report Emergency is now available to guests —
                      // ReportIncidentScreen relaxes its own required
                      // fields when isGuest is true.
                      _ActionTile(
                        label: 'Report\nEmergency',
                        icon: Icons.warning_amber_rounded,
                        iconColor: const Color(0xFFD32F2F),
                        bgColor: const Color(0xFFFFEBEE),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReportIncidentScreen(isGuest: isGuest),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        label: 'Emergency\nHotlines',
                        icon: Icons.phone_in_talk_outlined,
                        iconColor: const Color(0xFF00897B),
                        bgColor: const Color(0xFFE0F2F1),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EmergencyHotlinesScreen(isGuest: isGuest),
                          ),
                        ),
                      ),
                      _ActionTile(
                        label: 'Evacuation\nCenters',
                        icon: Icons.home_work_outlined,
                        iconColor: const Color(0xFF2E7D32),
                        bgColor: const Color(0xFFE8F5E9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EvacuationCentersScreen(),
                          ),
                        ),
                      ),
                      _ActionTile(
                        label: 'Disaster\nAlerts',
                        icon: Icons.notifications_active_outlined,
                        iconColor: const Color(0xFFF57C00),
                        bgColor: const Color(0xFFFFF3E0),
                        onTap: () {
                          if (isGuest) {
                            _showLoginRequired(context);
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AlertsScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        label: 'My Reports',
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF1565C0),
                        bgColor: const Color(0xFFE3F2FD),
                        onTap: () {
                          if (isGuest) {
                            _showLoginRequired(context);
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyReportsScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        label: 'Safety Tips',
                        icon: Icons.lightbulb_outline,
                        iconColor: const Color(0xFFF9A825),
                        bgColor: const Color(0xFFFFFDE7),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SafetyTipsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isGuest)
                    const _GuestAlertsPrompt()
                  else
                    _RecentAlertsCard(key: alertsCardKey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Login-Required Prompt ────────────────────────────────────────────────────

void _showLoginRequired(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Color(0xFF1A3A8F),
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Login Required',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please log in or create an account to use this feature.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A8F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'LOG IN',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Guest Alerts Prompt ───────────────────────────────────────────────────────

class _GuestAlertsPrompt extends StatelessWidget {
  const _GuestAlertsPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[400], size: 28),
          const SizedBox(height: 10),
          Text(
            'Log in to view recent alerts',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: const Color(0xFFE3F2FD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log In',
              style: TextStyle(
                color: Color(0xFF1A3A8F),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wave Ring ─────────────────────────────────────────────────────────────────

class _WaveRing extends StatelessWidget {
  final Animation<double> animation;
  final double maxRadius;
  final Color color;
  final double maxOpacity;

  const _WaveRing({
    required this.animation,
    required this.maxRadius,
    required this.color,
    required this.maxOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final size = maxRadius * 2 * animation.value;
    final opacity = ((1.0 - animation.value) * maxOpacity).clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}

// ── Bottom Curve Clipper ──────────────────────────────────────────────────────

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 40,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_BottomCurveClipper oldClipper) => false;
}

// ── Action Tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Alerts Card ──────────────────────────────────────────────────────

class _RecentAlertsCard extends StatefulWidget {
  const _RecentAlertsCard({super.key});

  @override
  State<_RecentAlertsCard> createState() => _RecentAlertsCardState();
}

class _RecentAlertsCardState extends State<_RecentAlertsCard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> refresh() => _loadAlerts();

  Future<void> _loadAlerts() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await ApiService.getAlerts();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success && result.data is List) {
        final cutoff = DateTime.now().subtract(const Duration(days: 3));
        _alerts = (result.data as List)
            .map((e) => e as Map<String, dynamic>)
            .where((alert) {
              final created = DateTime.tryParse(
                alert['created_at']?.toString() ?? '',
              );
              return created != null && created.isAfter(cutoff);
            })
            .take(3)
            .toList();
      }
    });
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final date = DateTime.tryParse(createdAt);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Alerts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00308F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (_alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No alerts yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            )
          else
            ..._alerts.map((alert) {
              final isAlertType = alert['type'] == 'Alerts';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isAlertType
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAlertType
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        color: isAlertType
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF1565C0),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          if (alert['subtitle'] != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              alert['subtitle'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      _timeAgo(alert['created_at']),
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
