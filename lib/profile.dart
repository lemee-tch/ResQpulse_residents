import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login.dart';
import 'home.dart';
import 'hotlines.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _citizen;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCitizen();
  }

  Future<void> _loadCitizen() async {
    final citizen = await ApiService.getUser();
    setState(() {
      _citizen = citizen;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _verificationBadge(String status) {
    late Color bg;
    late Color fg;
    late IconData icon;
    late String label;

    switch (status) {
      case 'verified':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        icon = Icons.verified;
        label = 'Verified Resident';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        icon = Icons.error_outline;
        label = 'ID Verification Failed';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.hourglass_top_rounded;
        label = 'Verification Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = _citizen?['full_name'] ?? 'Citizen';
    final String mobile = _citizen?['mobile'] ?? '';
    final String email = _citizen?['email'] ?? '';
    final String verificationStatus =
        _citizen?['verification_status'] ?? 'pending';
    final String? rejectionReason = _citizen?['rejection_reason'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1A1A2E),
            size: 20,
          ),
          onPressed: () {
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
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDE7F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF7B5EA7),
                      size: 52,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Phone / email
                  Text(
                    mobile.isNotEmpty ? mobile : email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color.fromARGB(255, 80, 79, 79),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Verification badge
                  _verificationBadge(verificationStatus),

                  if (verificationStatus == 'rejected' &&
                      rejectionReason != null &&
                      rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        rejectionReason,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Menu Items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _MenuItem(
                          icon: Icons.account_circle_outlined,
                          label: 'Personal Information',
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        _MenuItem(
                          icon: Icons.phone_outlined,
                          label: 'Emergency Contacts',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EmergencyHotlinesScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _MenuItem(
                          icon: Icons.notifications_outlined,
                          label: 'Notification Settings',
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        _MenuItem(
                          icon: Icons.star_outline_rounded,
                          label: 'About ResQPulse',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Logout
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text(
                                'Logout',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              content: const Text(
                                'Are you sure you want to logout?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A3A8F),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _handleLogout();
                                  },
                                  child: const Text(
                                    'Logout',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
