import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'phone_call.dart';

class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  String _query = '';

  // NOTE ON IMAGES:
  // Burns and Cuts have real pictures (assets/burn1.png …). The other
  // topics show a large icon for each step (`icon:`) until real pictures
  // are ready — they used to show 32 "Image unavailable" boxes. To add a
  // real picture to a step, give it an `image:` (it's shown instead of
  // the icon):
  //   - Network: image: 'https://yourcdn.com/images/cpr_step1.png'
  //   - Local:   image: 'assets/images/cpr_step1.png' (also list it under
  //              assets: in pubspec.yaml)
  // The _StepImage widget auto-detects which type it is.

  final List<_TipItem> _tips = const [
    // ── Fully detailed showcase topic (matches reference design) ──────────
    _TipItem(
      title: 'Burns',
      subtitle: 'Learn what to do',
      emoji: '🔥',
      color: Color(0xFFFF6D00),
      bgColor: Color(0xFFFFF3E0),
      guideTitle: 'BURNS – STEP-BY-STEP GUIDE',
      guideSubtitle: 'Follow these steps to help someone with a burn.',
      remember:
          'Act quickly, keep the burn clean and covered, and seek medical help when needed.',
      steps: [
        _StepItem(
          title: 'Cool the burn',
          bullets: [
            'Hold the burn under cool running water for 10–20 minutes.',
            'Do not use ice or very cold water.',
          ],
          timeBadge: '10-20 minutes',
          image: 'assets/burn1.png',
        ),
        _StepItem(
          title: 'Remove anything tight',
          bullets: [
            'Gently remove rings, watches, bracelets, or tight clothing near the burn.',
            'Do this while the skin is still cool to prevent swelling.',
          ],
          image: 'assets/burn2.png',
        ),
        _StepItem(
          title: 'Cover the burn',
          bullets: [
            'Cover the burn with a clean, dry cloth or sterile non-stick dressing.',
            'Do not use cotton or fluffy materials.',
          ],
          image: 'assets/burn3.png',
        ),
        _StepItem(
          title: 'Do NOT apply',
          bullets: [
            'Do not use butter, oil, toothpaste, alcohol, or home remedies.',
            'These can make the burn worse or cause infection.',
          ],
          dontApplyItems: ['🧈', '🛢️', '🦷', '🍶'],
          image: 'assets/burn4.png',
        ),
        _StepItem(
          title: 'Check the burn',
          bullets: [
            'Get medical help if the burn is larger than your palm.',
            'On the face, hands, feet, genitals, or major joints.',
            'Deep, white, charred, or blistered.',
            'Caused by chemicals or electricity.',
          ],
          checkGrid: [
            'Face',
            'Hands',
            'Deep / Blistered',
            'Chemical / Electrical',
          ],
          image: 'assets/burn5.png',
        ),
        _StepItem(
          title: 'Get medical help',
          bullets: [
            'Seek immediate medical care or call emergency services if the burn is severe or affects a sensitive area.',
          ],
          isEmergencyStep: true,
        ),
      ],
    ),

    // ── Remaining topics: simple bullet format, same layout ───────────────
    _TipItem(
      title: 'Cuts',
      subtitle: 'Learn what to do',
      emoji: '✂️',
      color: Color(0xFFD32F2F),
      bgColor: Color(0xFFFFEBEE),
      remember:
          'Keep the wound clean, covered, and watch for signs of infection. When in doubt, seek medical help.',
      steps: [
        _StepItem(
          title: 'Stay Safe',
          bullets: [
            'Make sure the area is safe.',
            'Put on gloves if available.',
          ],
          image: 'assets/cut1.png',
        ),
        _StepItem(
          title: 'Stop the bleeding',
          bullets: [
            'Apply gentle pressure with a clean cloth or gauze to stop bleeding.',
            'Elevate the injured area above heart level if possible.',
          ],
          image: 'assets/cut2.png',
        ),
        _StepItem(
          title: 'Clean the cut',
          bullets: [
            'Rinse the cut gently with clean water and mild soap.',
            'Remove any dirt or debris around the wound.',
          ],
          image: 'assets/cut3.png',
        ),
        _StepItem(
          title: 'Apply an antiseptic',
          bullets: [
            'Clean around the cut with an antiseptic solution,',
            'Do not put antiseptic directly inside the wound.',
          ],
          image: 'assets/cut4.png',
        ),
        _StepItem(
          title: 'Cover the cut',
          bullets: [
            'Cover with the sterile bandage or adhesive bandage.',
            'Change the bandage if it gets wet or dirty.',
          ],
          image: 'assets/cut5.png',
        ),
        _StepItem(
          title: 'Watch for infection (seek medical help if you notice:)',
          bullets: [
            'Redness, Swelling, or warmth',
            'Pus or unusual discharge',
            'increasing pain or tenderness',
            'fever or chills',
          ],
          image: 'assets/cut6.png',
        ),
        _StepItem(
          title: 'Get medical help',
          bullets: [
            'Get medical attention for deep cuts, heavy bleeding, or if the cut needs stitches.',
          ],
          image: 'assets/cut7.png',
        ),
      ],
    ),
    _TipItem(
      title: 'Fractures',
      subtitle: 'Learn what to do',
      emoji: '🦴',
      color: Color(0xFF5D4037),
      bgColor: Color(0xFFEFEBE9),
      remember: 'Never try to realign a suspected fracture yourself.',
      steps: [
        _StepItem(
          title: 'Keep it still',
          bullets: [
            'Keep the injured area still — do not try to straighten it.',
          ],
          icon: Icons.do_not_touch,
        ),
        _StepItem(
          title: 'Splint it',
          bullets: ['Apply a splint if available to immobilize the limb.'],
          icon: Icons.healing,
        ),
        _StepItem(
          title: 'Apply ice',
          bullets: ['Apply ice wrapped in cloth to reduce swelling.'],
          icon: Icons.ac_unit,
        ),
        _StepItem(
          title: 'Get help',
          bullets: ['Seek emergency medical help immediately.'],
          isEmergencyStep: true,
        ),
      ],
    ),
    _TipItem(
      title: 'CPR Guide',
      subtitle: 'Learn what to do',
      emoji: '❤️',
      color: Color(0xFFD32F2F),
      bgColor: Color(0xFFFFEBEE),
      remember: 'Push hard, push fast, and don\'t stop until help arrives.',
      steps: [
        _StepItem(
          title: 'Check & call',
          bullets: ['Check for responsiveness and call emergency services.'],
          // Shows the "Call MDRRMO" button.
          isEmergencyStep: true,
        ),
        _StepItem(
          title: 'Open the airway',
          bullets: ['Tilt the head back and lift the chin to open the airway.'],
          icon: Icons.face,
        ),
        _StepItem(
          title: 'Compress',
          bullets: [
            'Give 30 chest compressions hard and fast (2 inches deep).',
          ],
          icon: Icons.favorite,
        ),
        _StepItem(
          title: 'Breathe',
          bullets: ['Give 2 rescue breaths, then repeat the cycle.'],
          icon: Icons.air,
        ),
      ],
    ),
    _TipItem(
      title: 'Choking',
      subtitle: 'Learn what to do',
      emoji: '🫁',
      color: Color(0xFF1565C0),
      bgColor: Color(0xFFE3F2FD),
      remember: 'Alternate back blows and thrusts until the object clears.',
      steps: [
        _StepItem(
          title: 'Confirm choking',
          bullets: [
            'Ask the person if they are choking. If they can\'t speak, act fast.',
          ],
          icon: Icons.record_voice_over,
        ),
        _StepItem(
          title: 'Back blows',
          bullets: [
            'Give up to 5 firm back blows between the shoulder blades.',
          ],
          icon: Icons.back_hand,
        ),
        _StepItem(
          title: 'Abdominal thrusts',
          bullets: ['Give up to 5 abdominal thrusts (Heimlich maneuver).'],
          icon: Icons.compress,
        ),
        _StepItem(
          title: 'Repeat',
          bullets: [
            'Alternate back blows and abdominal thrusts until the object is cleared.',
          ],
          icon: Icons.repeat,
        ),
      ],
    ),

    _TipItem(
      title: 'Snake Bite',
      subtitle: 'Learn what to do',
      emoji: '🐍',
      color: Color(0xFF2E7D32),
      bgColor: Color(0xFFE8F5E9),
      remember: 'Do not cut the wound or attempt to suck out venom.',
      steps: [
        _StepItem(
          title: 'Stay calm and still',
          bullets: [
            'Keep the person calm and still — movement spreads venom faster.',
          ],
          icon: Icons.self_improvement,
        ),
        _StepItem(
          title: 'Remove tight items',
          bullets: [
            'Remove rings or tight clothing near the bite before swelling starts.',
          ],
          icon: Icons.watch,
        ),
        _StepItem(
          title: 'Immobilize',
          bullets: ['Loosely immobilize the limb below heart level.'],
          icon: Icons.airline_seat_recline_normal,
        ),
        _StepItem(
          title: 'Get to a hospital',
          bullets: ['Note the time of the bite and get to a hospital quickly.'],
          isEmergencyStep: true,
        ),
      ],
    ),
    _TipItem(
      title: 'Heat Stroke',
      subtitle: 'Learn what to do',
      emoji: '🥵',
      color: Color(0xFFEF6C00),
      bgColor: Color(0xFFFFF3E0),
      remember: 'Heat stroke is life-threatening — cool the body fast.',
      steps: [
        _StepItem(
          title: 'Move to shade',
          bullets: ['Move the person to a cool, shaded area immediately.'],
          icon: Icons.beach_access,
        ),
        _StepItem(
          title: 'Cool the body',
          bullets: [
            'Remove excess clothing and apply cool, wet cloths to skin.',
          ],
          icon: Icons.water_drop,
        ),
        _StepItem(
          title: 'Hydrate',
          bullets: ['Offer small sips of cool water if the person is alert.'],
          icon: Icons.local_drink,
        ),
        _StepItem(
          title: 'Monitor',
          bullets: ['Watch closely for confusion or loss of consciousness.'],
          isEmergencyStep: true,
        ),
      ],
    ),

    _TipItem(
      title: 'Nosebleed',
      subtitle: 'Learn what to do',
      emoji: '👃',
      color: Color(0xFFD81B60),
      bgColor: Color(0xFFFCE4EC),
      remember:
          'Avoid blowing the nose for several hours after bleeding stops.',
      steps: [
        _StepItem(
          title: 'Sit forward',
          bullets: ['Sit up and lean slightly forward.'],
          icon: Icons.event_seat,
        ),
        _StepItem(
          title: 'Pinch the nose',
          bullets: [
            'Pinch the soft part of the nose firmly for 10-15 minutes.',
          ],
          timeBadge: '10-15 minutes',
          icon: Icons.pinch,
        ),
        _StepItem(
          title: 'Apply cold compress',
          bullets: ['Apply a cold compress to the bridge of the nose.'],
          icon: Icons.ac_unit,
        ),
        _StepItem(
          title: 'Avoid blowing',
          bullets: ['Avoid blowing the nose for several hours after.'],
          icon: Icons.block,
        ),
      ],
    ),
    _TipItem(
      title: 'Allergic Reaction',
      subtitle: 'Learn what to do',
      emoji: '🤧',
      color: Color(0xFF6A1B9A),
      bgColor: Color(0xFFF3E5F5),
      remember: 'Anaphylaxis can be fatal within minutes — act immediately.',
      steps: [
        _StepItem(
          title: 'Remove the allergen',
          bullets: ['Remove the person from the allergen source if possible.'],
          icon: Icons.directions_walk,
        ),
        _StepItem(
          title: 'Use an EpiPen',
          bullets: [
            'Use an epinephrine auto-injector on the outer thigh if available.',
          ],
          icon: Icons.vaccines,
        ),
        _StepItem(
          title: 'Position them',
          bullets: [
            'Lay them flat and elevate legs, unless breathing is difficult.',
          ],
          icon: Icons.airline_seat_flat,
        ),
        _StepItem(
          title: 'Monitor',
          bullets: ['Monitor breathing closely and be ready to start CPR.'],
          isEmergencyStep: true,
        ),
      ],
    ),
    _TipItem(
      title: 'Earthquake',
      subtitle: 'Learn what to do',
      emoji: '🏚️',
      color: Color(0xFF6D4C41),
      bgColor: Color(0xFFEFEBE9),
      remember: 'Drop, cover, and hold on until shaking fully stops.',
      steps: [
        _StepItem(
          title: 'Drop',
          bullets: ['DROP to hands and knees immediately.'],
          icon: Icons.arrow_downward,
        ),
        _StepItem(
          title: 'Cover',
          bullets: [
            'Take COVER under a sturdy table or against an interior wall.',
          ],
          icon: Icons.table_restaurant,
        ),
        _StepItem(
          title: 'Hold on',
          bullets: ['HOLD ON until the shaking stops.'],
          icon: Icons.pan_tool,
        ),
        _StepItem(
          title: 'Evacuate carefully',
          bullets: [
            'After shaking stops, evacuate carefully and avoid damaged structures.',
          ],
          icon: Icons.directions_walk,
        ),
      ],
    ),
    _TipItem(
      title: 'Flood Safety',
      subtitle: 'Learn what to do',
      emoji: '🌧️',
      color: Color(0xFF1565C0),
      bgColor: Color(0xFFE3F2FD),
      remember: 'Never walk or drive through floodwater — turn back.',
      steps: [
        _StepItem(
          title: 'Move to higher ground',
          bullets: ['Move to higher ground immediately.'],
          icon: Icons.terrain,
        ),
        _StepItem(
          title: 'Avoid floodwater',
          bullets: ['Do not walk or drive through floodwater.'],
          icon: Icons.flood,
        ),
        _StepItem(
          title: 'Turn off utilities',
          bullets: ['Turn off utilities at the main switch if safe to do so.'],
          icon: Icons.power_off,
        ),
        _StepItem(
          title: 'Follow alerts',
          bullets: [
            'Listen to emergency broadcasts and follow evacuation orders.',
          ],
          icon: Icons.campaign,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    final filtered = _tips
        .where((t) => t.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

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
          'First Aid Guide',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search first aid topics...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No topics found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _TipCard(tip: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Tip Card ──────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final _TipItem tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _TipDetailScreen(tip: tip)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: tip.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(tip.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tip.subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Tip Detail Screen ─────────────────────────────────────────────────────────

class _TipDetailScreen extends StatelessWidget {
  final _TipItem tip;
  const _TipDetailScreen({required this.tip});

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          tip.title,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card (icon + title + subtitle)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        tip.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tip.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),

            // Guide title + subtitle
            if (tip.guideTitle != null) ...[
              Center(
                child: Text(
                  tip.guideTitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tip.color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (tip.guideSubtitle != null) ...[
              Center(
                child: Text(
                  tip.guideSubtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (tip.guideTitle == null) const SizedBox(height: 6),

            // Steps
            ...tip.steps.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final step = entry.value;
              return _StepCard(
                step: step,
                index: i,
                color: tip.color,
                bgColor: tip.bgColor,
              );
            }),

            const SizedBox(height: 4),

            // Remember footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1565C0).withOpacity(0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF1565C0),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A2E),
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Remember: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          TextSpan(
                            text:
                                tip.remember ??
                                'Stay calm, act quickly, and seek medical help when needed.',
                          ),
                        ],
                      ),
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

// ── Step Card ──────────────────────────────────────────────────────────────────
// Layout order kept as: number+title -> bullets -> optional extras (icon grid /
// body-check grid / emergency card) -> IMAGE full-width BELOW everything else.

class _StepCard extends StatelessWidget {
  final _StepItem step;
  final int index;
  final Color color;
  final Color bgColor;

  const _StepCard({
    required this.step,
    required this.index,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number + title + time badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (step.timeBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        step.timeBadge!,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Bullets
          if (step.bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: step.bullets.map((b) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(
                            Icons.circle,
                            size: 5,
                            color: Color(0xFF555555),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF333333),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Don't-apply icon grid
          if (step.dontApplyItems != null &&
              step.dontApplyItems!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: step.dontApplyItems!
                    .map((emoji) => _DontApplyChip(emoji: emoji))
                    .toList(),
              ),
            ),
          ],

          // Body-check diagram grid
          if (step.checkGrid != null && step.checkGrid!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: step.checkGrid!
                    .map((label) => _CheckGridTile(label: label, color: color))
                    .toList(),
              ),
            ),
          ],

          // Full-width picture — stays BELOW description/extras, per the
          // existing layout: the step's real image when it has one,
          // otherwise its icon.
          if (!step.isEmergencyStep && _hasPicture(step.image)) ...[
            const SizedBox(height: 12),
            _StepImage(
              imageSource: step.image!,
              fallbackIcon: step.icon,
              color: color,
            ),
          ] else if (!step.isEmergencyStep && step.icon != null) ...[
            const SizedBox(height: 12),
            _StepIllustration(icon: step.icon!, color: color),
          ],

          // "Get help" steps: a button that calls MDRRMO right away.
          if (step.isEmergencyStep) ...[
            const SizedBox(height: 12),
            const _EmergencyCallCard(),
          ],
        ],
      ),
    );
  }

  /// A real picture: an asset in the app or an image online.
  static bool _hasPicture(String? image) =>
      image != null &&
      (image.startsWith('assets/') || image.startsWith('http'));
}

// ── Don't Apply Chip ──────────────────────────────────────────────────────────

class _DontApplyChip extends StatelessWidget {
  final String emoji;
  const _DontApplyChip({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const Icon(Icons.close, color: Colors.red, size: 30),
        ],
      ),
    );
  }
}

// ── Body Check Grid Tile ──────────────────────────────────────────────────────

class _CheckGridTile extends StatelessWidget {
  final String label;
  final Color color;
  const _CheckGridTile({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Emergency Call Card ────────────────────────────────────────────────────────
// Shown on the "Get help" steps (isEmergencyStep). The model always said
// these steps show a call card, but there wasn't one.

class _EmergencyCallCard extends StatelessWidget {
  const _EmergencyCallCard();

  static const Color _red = Color(0xFFD32F2F);

  Future<void> _call(BuildContext context) async {
    final opened = await openDialer('#2441');
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _red.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: _red, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Need help now? Call MDRRMO Rosales.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _call(context),
            icon: const Icon(Icons.call, size: 16),
            label: const Text(
              '#2441',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step Illustration ─────────────────────────────────────────────────────────
// A large icon for a step that has no picture yet (it used to be an
// "Image unavailable" box).

class _StepIllustration extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StepIllustration({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 36),
        ),
      ),
    );
  }
}

// ── Image Widget ──────────────────────────────────────────────────────────────
// Renders a static image (asset or network). Works for any image format
// (.png, .jpg, .webp, etc.) — nothing here is GIF-specific. If it can't
// load, the step's icon is shown instead of an "Image unavailable" box.

class _StepImage extends StatelessWidget {
  final String imageSource;
  final IconData? fallbackIcon;
  final Color color;
  final double height;

  const _StepImage({
    required this.imageSource,
    required this.fallbackIcon,
    required this.color,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNetwork = imageSource.startsWith('http');

    final Widget image = isNetwork
        ? Image.network(
            imageSource,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _loading();
            },
            errorBuilder: (context, error, stack) => _fallback(),
          )
        : Image.asset(
            imageSource,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _fallback(),
          );

    return ClipRRect(borderRadius: BorderRadius.circular(10), child: image);
  }

  Widget _fallback() => _StepIllustration(
    icon: fallbackIcon ?? Icons.medical_services_outlined,
    color: color,
  );

  Widget _loading() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _StepItem {
  final String title;
  final List<String> bullets;
  final String? image; // a real picture: 'assets/…' or 'https://…'
  final IconData? icon; // shown when the step has no picture
  final String? timeBadge;
  final List<String>? dontApplyItems; // emoji list, rendered with red X overlay
  final List<String>? checkGrid; // labels for body-check style tiles
  final bool isEmergencyStep; // renders call card instead of image

  const _StepItem({
    required this.title,
    this.bullets = const [],
    this.image,
    this.icon,
    this.timeBadge,
    this.dontApplyItems,
    this.checkGrid,
    this.isEmergencyStep = false,
  });
}

class _TipItem {
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final Color bgColor;
  final String? guideTitle;
  final String? guideSubtitle;
  final String? remember;
  final List<_StepItem> steps;

  const _TipItem({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.bgColor,
    this.guideTitle,
    this.guideSubtitle,
    this.remember,
    required this.steps,
  });
}
