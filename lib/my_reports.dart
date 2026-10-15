import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

// ── My Reports — List Screen ────────────────────────────────────────────────

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_ReportData> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getMyIncidents();

    if (!mounted) return;

    if (result.success && result.data is List) {
      setState(() {
        _reports = (result.data as List)
            .map((e) => _ReportData.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Could not load your reports.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1A1A2E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Reports',
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
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadReports,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _reports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your submitted reports will appear here',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  return _ReportCard(
                    report: report,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportStatusScreen(report: report),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ── Report Card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final _ReportData report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  static const Map<String, IconData> _typeIcons = {
    'Fire': Icons.local_fire_department_outlined,
    'Flood': Icons.water_outlined,
    'Earthquake': Icons.landscape_outlined,
    'Accident': Icons.car_crash_outlined,
    'Medical Emergency': Icons.medical_services_outlined,
    'Landslide': Icons.terrain_outlined,
  };

  IconData get _icon => report.isSos
      ? Icons.sos
      : (_typeIcons[report.emergencyType] ?? Icons.warning_amber_rounded);

  /// Red for an SOS, so it stands out from regular reports.
  Color get _iconColor =>
      report.isSos ? const Color(0xFFD32F2F) : const Color(0xFF1A3A8F);

  /// "Responding: Juan Dela Cruz" / "Responding: Juan Dela Cruz +2 more" —
  /// same summarizing pattern the responder app's own home screen uses
  /// (see responder_home.dart's _IncidentCard), so a citizen sees at a
  /// glance whether anyone from MDRRMO has picked up their report yet,
  /// without opening it.
  String? get _teamSummary {
    if (report.responders.isEmpty) return null;
    final lead = _sortedResponders(report.responders).first;
    final name = lead['full_name']?.toString() ?? 'Responder';
    return report.responders.length == 1
        ? 'Accepted by: $name'
        : 'Accepted by: $name +${report.responders.length - 1} backup';
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(report.displayStatus);
    final teamSummary = _teamSummary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusStyle.bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusStyle.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusStyle.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    report.location,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if (teamSummary != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            teamSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    report.formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Report Status — Timeline Detail Screen ──────────────────────────────────

class ReportStatusScreen extends StatelessWidget {
  final _ReportData report;
  const ReportStatusScreen({super.key, required this.report});

  static const List<_StatusStep> _steps = [
    _StatusStep(
      key: 'pending',
      title: 'Pending',
      subtitle: 'Your report has been received',
    ),
    _StatusStep(
      key: 'responding',
      title: 'Responding',
      subtitle: 'Responders are on the way',
    ),
    _StatusStep(
      key: 'resolved',
      title: 'Resolved',
      subtitle: 'Incident has been resolved.',
    ),
  ];

  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _amber = Color(0xFFF9A825);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _grey = Color(0xFFD1D5DB);

  int get _currentIndex {
    // 'for_review': the responders are done and MDRRMO is checking their
    // report — still the Responding step, not Resolved yet.
    final key = report.status == 'for_review' ? 'responding' : report.status;
    final idx = _steps.indexWhere((s) => s.key == key);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final bool declined = report.declined;
    final int currentIndex = declined ? -1 : _currentIndex;
    final bool isResolved = report.status == 'resolved';
    final Color activeColor = declined ? _grey : (isResolved ? _green : _amber);

    // The first step says whether MDRRMO is still reviewing the report or
    // has already sent it to responders; the second, whether the
    // responders are still on it or have finished (MDRRMO then checks
    // their report before marking it resolved).
    final bool responded = report.status == 'for_review';
    final List<_StatusStep> steps = [
      _StatusStep(
        key: 'pending',
        title: report.needsReview ? 'Under Review' : 'Pending',
        subtitle: report.needsReview
            ? 'MDRRMO is checking your report. Responders are sent once it\'s approved.'
            : 'Sent to responders — waiting for one to accept',
      ),
      responded
          ? const _StatusStep(
              key: 'responding',
              title: 'Responded',
              subtitle:
                  'The responders are done. MDRRMO is checking their report '
                  'before marking it resolved.',
            )
          : _steps[1],
      _steps[2],
    ];

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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Incident Status',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (declined) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.block, color: Color(0xFF991B1B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (report.declineReason ?? '').trim().isNotEmpty
                            ? 'MDRRMO declined this report: ${report.declineReason!.trim()}'
                            : 'MDRRMO declined this report.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF991B1B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // "Your Report" node — filled navy (red for an SOS), connects
            // down with navy/amber (something is already in motion)
            // toward Pending.
            _TimelineRow(
              circleColor: report.isSos ? const Color(0xFFD32F2F) : _navy,
              icon: report.isSos ? Icons.sos : Icons.description,
              lineBelowColor: activeColor,
              title: report.isSos ? 'Your SOS' : 'Your Report',
              subtitleLines: [
                report.isSos
                    ? report.title
                    : '${report.emergencyType} incident',
                if (report.location.isNotEmpty) report.location,
                report.formattedDate,
              ],
            ),

            ...steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final bool reached = i <= currentIndex;
              final bool isLast = i == steps.length - 1;

              final Color circleColor = reached ? activeColor : _grey;
              final Color lineColor = (!isLast && i < currentIndex)
                  ? activeColor
                  : _grey;

              return _TimelineRow(
                circleColor: circleColor,
                lineBelowColor: isLast ? null : lineColor,
                title: step.title,
                subtitleLines: [step.subtitle],
                dimmed: !reached,
              );
            }),

            // ── RESPONDING TEAM ──────────────────────────────────────
            // Mirrors the admin "Responding Team" panel on sos-details
            // .blade.php — same source data (Incident::responders(), the
            // incident_responder pivot), just rendered for the citizen.
            // Hidden entirely while nobody has accepted yet, since the
            // "Pending" timeline step already conveys that.
            if (report.responders.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 20),
              Text(
                report.responders.length == 1
                    ? 'Responding Team'
                    : 'Responding Team (${report.responders.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              ..._sortedResponders(report.responders).asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  // First to accept (earliest pivot.accepted_at) is the
                  // one who took the mission; anyone who joined after
                  // them is backup support — mirrors the acceptance
                  // model in IncidentController::accept() ("First
                  // acceptance moves the incident out of 'pending';
                  // later joins are backup").
                  child: _ResponderTile(
                    responder: entry.value,
                    isLead: entry.key == 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Earliest pivot.accepted_at first — that responder is the one who
/// actually accepted the mission; everyone else on the list joined
/// after them as backup. Responders with no accepted_at (shouldn't
/// normally happen — accept() always sets it) sort last so they don't
/// falsely claim the lead spot.
List<Map<String, dynamic>> _sortedResponders(
  List<Map<String, dynamic>> responders,
) {
  DateTime? acceptedAt(Map<String, dynamic> r) {
    final pivot = r['pivot'];
    final raw = pivot is Map ? pivot['accepted_at']?.toString() : null;
    return DateTime.tryParse(raw ?? '');
  }

  final sorted = List<Map<String, dynamic>>.from(responders);
  sorted.sort((a, b) {
    final da = acceptedAt(a);
    final db = acceptedAt(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return sorted;
}

// ── Responder Tile (one row per team member on "Responding Team") ─────────

class _ResponderTile extends StatelessWidget {
  final Map<String, dynamic> responder;
  final bool isLead;
  const _ResponderTile({required this.responder, required this.isLead});

  String get _name => responder['full_name']?.toString() ?? 'Responder';
  String? get _agency => responder['agency']?.toString();

  String? get _joinedAt {
    final pivot = responder['pivot'];
    final raw = pivot is Map ? pivot['accepted_at']?.toString() : null;
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final prefix = isLead ? 'Accepted' : 'Backed up';
    return '$prefix ${months[date.month - 1]} ${date.day}, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (_agency != null && _agency!.isNotEmpty) _agency!,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isLead ? const Color(0xFFD1FAE5) : const Color(0xFFE0F2FE),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isLead ? Icons.shield_moon : Icons.shield_outlined,
            color: isLead ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isLead
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLead ? 'Accepted mission' : 'Backup',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isLead
                            ? const Color(0xFF065F46)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitleParts.isNotEmpty)
                Text(
                  subtitleParts.join(' · '),
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
              if (_joinedAt != null)
                Text(
                  _joinedAt!,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[400]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Timeline Row (shared by "Your Report" + each status step) ─────────────

class _TimelineRow extends StatelessWidget {
  final Color circleColor;
  final Color? lineBelowColor;
  final IconData? icon;
  final String title;
  final List<String> subtitleLines;
  final bool dimmed;

  const _TimelineRow({
    required this.circleColor,
    required this.lineBelowColor,
    this.icon,
    required this.title,
    required this.subtitleLines,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: icon != null ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: icon != null ? BorderRadius.circular(12) : null,
                ),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: Colors.white, size: 18)
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
              if (lineBelowColor != null)
                Expanded(child: Container(width: 3, color: lineBelowColor)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: dimmed
                          ? Colors.grey[400]
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...subtitleLines.map(
                    (line) => Text(
                      line,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: dimmed ? Colors.grey[350] : Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _StatusStep {
  final String key;
  final String title;
  final String subtitle;
  const _StatusStep({
    required this.key,
    required this.title,
    required this.subtitle,
  });
}

class _ReportData {
  final int id;
  final String emergencyType;
  final String location;
  final String description;
  final String status;
  final DateTime? createdAt;
  final List<Map<String, dynamic>> responders;

  /// For an SOS: the emergency picked on the SOS screen (Fire, Flood…),
  /// if any. The server keeps it apart from emergency_type, which is
  /// always "SOS Emergency" for an SOS.
  final String? sosType;

  // Every report waits for MDRRMO to review it before responders are sent
  // (needs_review). An admin can also decline it, with a reason.
  final bool needsReview;
  final bool declined;
  final String? declineReason;

  const _ReportData({
    required this.id,
    required this.emergencyType,
    required this.location,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.responders,
    this.sosType,
    this.needsReview = false,
    this.declined = false,
    this.declineReason,
  });

  /// Sent with the SOS button, not the report form.
  bool get isSos => emergencyType == 'SOS Emergency';

  /// What the card calls it: "SOS Alert — Fire" for an SOS (it used to
  /// say just "SOS Emergency"), the emergency type for a report.
  String get title {
    if (!isSos) return emergencyType;
    final type = sosType?.trim() ?? '';
    return type.isEmpty ? 'SOS Alert' : 'SOS Alert — $type';
  }

  /// The server starts an SOS's location with "SOS Alert — " (and a guest
  /// report's with "Guest Report — ") so MDRRMO can tell them apart in its
  /// lists. The resident only needs the place.
  static String _placeOnly(String location) {
    final place = location
        .replaceFirst(RegExp(r'^(SOS Alert|Guest Report)\s*[—–,-]\s*'), '')
        .trim();
    return place.isEmpty ? location : place;
  }

  /// What the badge shows: 'review', 'declined', or the server status
  /// ('pending', 'responding', 'for_review', 'resolved'). 'for_review'
  /// means the responders are done and MDRRMO is checking their report.
  String get displayStatus {
    if (declined) return 'declined';
    if (needsReview) return 'review';
    return status;
  }

  factory _ReportData.fromJson(Map<String, dynamic> json) {
    return _ReportData(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      emergencyType: json['emergency_type']?.toString() ?? 'Emergency',
      location: _placeOnly(json['location']?.toString() ?? ''),
      sosType: json['sos_emergency_type']?.toString(),
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
      // Comes straight from Incident::with('responders') on the backend
      // (IncidentController::mine) — each entry carries full_name,
      // agency, badge_number and a pivot.accepted_at, same shape the
      // admin's sos-details.blade.php "Responding Team" panel already
      // reads. Defensive parsing since older cached responses or a
      // report with no one assigned yet may not carry the key at all.
      responders: (json['responders'] is List)
          ? (json['responders'] as List)
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList()
          : <Map<String, dynamic>>[],
      needsReview:
          json['needs_review'] == true ||
          json['needs_review'] == 1 ||
          json['needs_review']?.toString() == '1',
      declined: (json['declined_at']?.toString() ?? '').isNotEmpty,
      declineReason: json['decline_reason']?.toString(),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get formattedDate {
    final date = createdAt;
    if (date == null) return '';
    final month = _months[date.month - 1];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month ${date.day}, ${date.year} – $hour12:$minute $period';
  }
}

class _StatusStyle {
  final Color bg;
  final Color fg;
  final String label;
  const _StatusStyle({required this.bg, required this.fg, required this.label});
}

_StatusStyle _statusStyle(String status) {
  switch (status) {
    case 'review':
      return const _StatusStyle(
        bg: Color(0xFFEDE9FE),
        fg: Color(0xFF5B21B6),
        label: 'Under Review',
      );
    case 'declined':
      return const _StatusStyle(
        bg: Color(0xFFFEE2E2),
        fg: Color(0xFF991B1B),
        label: 'Declined',
      );
    case 'responding':
      return const _StatusStyle(
        bg: Color(0xFFE0F2FE),
        fg: Color(0xFF0369A1),
        label: 'Responding',
      );
    case 'for_review':
      return const _StatusStyle(
        bg: Color(0xFFCCFBF1),
        fg: Color(0xFF0F766E),
        label: 'Responded',
      );
    case 'resolved':
      return const _StatusStyle(
        bg: Color(0xFFD1FAE5),
        fg: Color(0xFF065F46),
        label: 'Resolved',
      );
    default:
      return const _StatusStyle(
        bg: Color(0xFFFEF3C7),
        fg: Color(0xFF92400E),
        label: 'Pending',
      );
  }
}
