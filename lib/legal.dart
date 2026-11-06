import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'phone_call.dart';

/// Privacy Policy, Terms and Conditions, Cookie Policy and Accessibility
/// (item 64) — one copy for both apps: this file is the same in the
/// ResQPulse and Resqponder apps. The website shows the same text
/// (resqpulse.com/privacy-policy and so on, App\Support\Legal on the
/// server). When the text changes, change all three and kLegalVersion.

/// Version of the documents below. Sent with the sign-up consent, so
/// MDRRMO knows which version a resident agreed to.
const String kLegalVersion = '2026-11-05';

/// Shown at the top of each document.
const String kLegalUpdated = 'November 5, 2026';

/// Where the documents are on the web.
const String kLegalWebsite = 'resqpulse.com';

const String _mdrrmoNumber = '#2441';

enum LegalDoc { privacy, terms, cookies, accessibility }

extension LegalDocInfo on LegalDoc {
  _LegalDocument get _document => _documents.firstWhere((d) => d.doc == this);

  /// "Privacy Policy", "Terms and Conditions", …
  String get title => _document.title;

  /// One line about what's in it, for lists of the documents.
  String get summary => _document.summary;

  /// e.g. "resqpulse.com/privacy-policy".
  String get webAddress => '$kLegalWebsite/${_document.path}';

  IconData get icon => switch (this) {
    LegalDoc.privacy => Icons.privacy_tip_outlined,
    LegalDoc.terms => Icons.gavel_rounded,
    LegalDoc.cookies => Icons.cookie_outlined,
    LegalDoc.accessibility => Icons.accessibility_new_rounded,
  };
}

/// Opens one of the documents.
Future<void> openLegal(
  BuildContext context,
  LegalDoc doc, {
  Color accent = _defaultAccent,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalScreen(doc: doc, accent: accent),
    ),
  );
}

const Color _defaultAccent = Color(0xFF1A3A8F);
const Color _ink = Color(0xFF111827);
const Color _body = Color(0xFF374151);
const Color _muted = Color(0xFF4B5563);

/// One document, with "On this page" links to its sections.
///
/// Accessibility: the title and section names are headings for screen
/// readers, the text follows the phone's font size, and every color here
/// has at least 4.5:1 contrast on white.
class LegalScreen extends StatefulWidget {
  final LegalDoc doc;
  final Color accent;

  const LegalScreen({
    super.key,
    required this.doc,
    this.accent = _defaultAccent,
  });

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final List<GlobalKey> _sectionKeys = List.generate(
    widget.doc._document.sections.length,
    (_) => GlobalKey(),
  );

  void _goTo(int index) {
    final context = _sectionKeys[index].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.02,
    );
  }

  Future<void> _call() async {
    final opened = await openDialer(_mdrrmoNumber);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open the phone app. Dial #2441 to reach MDRRMO Rosales.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.doc._document;
    final accent = widget.accent;

    return Scaffold(
      backgroundColor: Colors.white,
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
        title: Text(
          document.title,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  document.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last updated: $kLegalUpdated',
                style: const TextStyle(fontSize: 13.5, color: _muted),
              ),
              const SizedBox(height: 16),
              for (final paragraph in document.intro) ...[
                _LegalText(paragraph),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              _contents(document, accent),
              for (var i = 0; i < document.sections.length; i++)
                _section(document.sections[i], _sectionKeys[i]),
              const SizedBox(height: 28),
              _footer(document, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contents(_LegalDocument document, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'On this page',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < document.sections.length; i++)
            MergeSemantics(
              child: Semantics(
                button: true,
                hint: 'Goes to this section',
                child: InkWell(
                  onTap: () => _goTo(i),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              document.sections[i].heading,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: accent,
                                decoration: TextDecoration.underline,
                                decorationColor: accent.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(_LegalSection section, Key key) {
    final children = <Widget>[];
    final bullets = <String>[];

    void flushBullets() {
      for (final bullet in bullets) {
        children.add(_Bullet(bullet.substring(2)));
      }
      bullets.clear();
    }

    for (final block in section.blocks) {
      if (block.startsWith('• ')) {
        bullets.add(block);
      } else {
        flushBullets();
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LegalText(block),
          ),
        );
      }
    }
    flushBullets();

    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              section.heading,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _ink,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _footer(_LegalDocument document, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questions?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Call MDRRMO Rosales at #2441, or visit the MDRRMO office.',
            style: TextStyle(fontSize: 14.5, color: _body, height: 1.45),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _call,
              icon: Icon(Icons.phone_in_talk, size: 18, color: accent),
              label: Text(
                'Call MDRRMO Rosales',
                semanticsLabel: 'Call MDRRMO Rosales at #2441',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withOpacity(0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            'Also online at $kLegalWebsite/${document.path}',
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }
}

/// The four documents as a list of rows — About uses it in both apps.
class LegalLinks extends StatelessWidget {
  final Color accent;

  const LegalLinks({super.key, this.accent = _defaultAccent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final doc in LegalDoc.values) ...[
          MergeSemantics(
            child: Semantics(
              button: true,
              child: InkWell(
                onTap: () => openLegal(context, doc, accent: accent),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(doc.icon, color: accent, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.title,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                doc.summary,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.chevron_right,
                            color: _muted,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (doc != LegalDoc.values.last)
            const Divider(height: 8, color: Color(0xFFE5E7EB)),
        ],
      ],
    );
  }
}

/// A short notice under a form, with buttons to the documents it names —
/// e.g. on SOS, a report or the evacuee form (item 64). It informs; it
/// never blocks sending, so it can't slow down an emergency.
class PrivacyNote extends StatelessWidget {
  final String text;
  final List<LegalDoc> links;
  final Color accent;

  const PrivacyNote(
    this.text, {
    super.key,
    this.links = const [LegalDoc.privacy],
    this.accent = _defaultAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.shield_outlined, size: 17, color: _muted),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 4,
          children: [
            for (final doc in links)
              TextButton(
                onPressed: () => openLegal(context, doc, accent: accent),
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                child: Text(doc.title),
              ),
          ],
        ),
      ],
    );
  }
}

/// A paragraph; **text** is bold.
class _LegalText extends StatelessWidget {
  final String text;

  const _LegalText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans(text)),
      style: const TextStyle(fontSize: 15, color: _body, height: 1.5),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 10, 0),
              child: Text(
                '•',
                style: TextStyle(fontSize: 15, color: _body, height: 1.5),
              ),
            ),
          ),
          Expanded(child: _LegalText(text)),
        ],
      ),
    );
  }
}

List<InlineSpan> _spans(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        TextSpan(
          text: parts[i],
          style: i.isOdd
              ? const TextStyle(fontWeight: FontWeight.w700, color: _ink)
              : null,
        ),
  ];
}

class _LegalDocument {
  final LegalDoc doc;
  final String title;
  final String path;
  final String summary;
  final List<String> intro;
  final List<_LegalSection> sections;

  const _LegalDocument({
    required this.doc,
    required this.title,
    required this.path,
    required this.summary,
    required this.intro,
    required this.sections,
  });
}

class _LegalSection {
  final String heading;

  /// A paragraph each; "• " starts a bullet.
  final List<String> blocks;

  const _LegalSection(this.heading, this.blocks);
}

// ── The documents ─────────────────────────────────────────────────────
// Made from one source with the website's copy (App\Support\Legal).

const List<_LegalDocument> _documents = [
  _LegalDocument(
    doc: LegalDoc.privacy,
    title: 'Privacy Policy',
    path: 'privacy-policy',
    summary: 'What we collect, why, who sees it and your rights',
    intro: [
      'This Privacy Policy explains what personal information ResQPulse '
          'collects, why, who sees it, how long it is kept, and your rights '
          'under the Data Privacy Act of 2012 (Republic Act No. 10173).',
      'It covers the ResQPulse app for residents, the Resqponder app for '
          'response teams, and the MDRRMO web panel at resqpulse.com.',
    ],
    sections: [
      _LegalSection('Who we are', [
        'ResQPulse is run by the Municipal Disaster Risk Reduction and '
            'Management Office (MDRRMO) of the Municipality of Rosales, '
            'Pangasinan. MDRRMO Rosales decides how your information is used '
            '(it is the "personal information controller"). In this policy, '
            '"MDRRMO", "we" and "us" mean MDRRMO Rosales.',
        '**Questions or requests:** Call MDRRMO Rosales at #2441, or visit '
            'the MDRRMO office, and ask for the Data Protection Officer of the '
            'Municipality of Rosales.',
      ]),
      _LegalSection('What we collect from residents (ResQPulse app)', [
        '• **Your account:** your first, middle and last name, suffix, '
            'mobile number, email (if you use one), password, and your address '
            'in Rosales (barangay, street and zone). Your password is stored '
            'scrambled (hashed), so nobody can read it, not even MDRRMO.',
        '• **Proof of residency:** a photo of a valid ID. The law treats '
            'government-issued IDs as sensitive personal information. We use '
            'it only to confirm that you live in Rosales.',
        '• **SOS alerts and reports:** the kind of emergency, what you '
            'write, the photos you take, your location (GPS coordinates and '
            'how accurate they are), the barangay and nearest landmark worked '
            'out from it, and the time.',
        '• **Guests:** if you send an SOS without an account, the name and '
            'mobile number you enter, with the details above.',
        '• **Your phone:** a notification token, so we can send you '
            'alerts, and the internet (IP) address that reaches our server.',
      ]),
      _LegalSection('What we collect from response teams and staff', [
        '• **Resqponder accounts:** the agency, station or unit, badge '
            'number, email and mobile number of each agency account.',
        '• **What teams record:** incidents they accept or decline, team '
            'reports and their photos, backup requests, and evacuation centers '
            'with their location.',
        '• **Evacuees:** the name, age, sex, barangay and contact number '
            'of people logged at evacuation centers. The law treats age as '
            'sensitive personal information.',
        '• **MDRRMO staff:** name, email, and a record of what each person '
            'does in the web panel (the Audit Log).',
      ]),
      _LegalSection('How your location is used', [
        '• ResQPulse sends your location to MDRRMO only when you send an '
            'SOS or a report.',
        '• On Evacuation Centers, your location is used on your phone to '
            'show the nearest centers. It is not sent to us.',
        '• To show the address of a report, your phone looks up the place '
            'at your location with OpenStreetMap\'s search service (Nominatim).',
        '• Resqponder uses the phone\'s location on the phone to show maps '
            'and routes. To draw a route, the phone sends the start and end '
            'points to the OSRM route service. A team\'s location is not sent '
            'to MDRRMO, except the location of an evacuation center they add.',
      ]),
      _LegalSection('Why we use your information', [
        '• To receive, check and respond to SOS alerts and reports, and to '
            'send the right responders.',
        '• To confirm that an account belongs to a resident of Rosales, '
            'and to keep accounts secure (codes and limits on wrong passwords).',
        '• To send disaster alerts, and updates about your reports.',
        '• To keep evacuation and relief records.',
        '• To prevent and deal with misuse, such as false reports.',
        '• For disaster planning and statistics, using totals that don\'t '
            'identify anyone.',
        '• To keep the records the law requires.',
      ]),
      _LegalSection('Our legal basis', [
        'Under Sections 12 and 13 of the Data Privacy Act, we use your '
            'information because:',
        '• you agreed to it when you created your account, including '
            'specifically for your ID photo (Sections 12(a) and 13(a));',
        '• it is needed to protect someone\'s life and health in an '
            'emergency (Sections 12(d) and 13(c));',
        '• it is needed to respond to emergencies, keep public order and '
            'safety, and carry out MDRRMO\'s duties under the Philippine '
            'Disaster Risk Reduction and Management Act of 2010 (Republic Act '
            'No. 10121) (Sections 12(e) and 13(b));',
        '• the law requires it, for example to keep public records '
            '(Section 12(c)).',
      ]),
      _LegalSection('The AI photo check', [
        'When an SOS or a report includes a photo, our server may send the '
            'photo to Google\'s Gemini AI service to suggest what kind of '
            'emergency it shows. The suggestion is only a hint for MDRRMO '
            'staff and responders. A person always checks the report and '
            'decides what to do; the AI does not decide whether help is sent.',
      ]),
      _LegalSection('Who sees your information', [
        '• **MDRRMO Rosales staff** who handle reports and accounts.',
        '• **The response teams sent to help** (for example police, fire, '
            'rescue, health and social welfare teams). They see what they need '
            'to respond: your name, mobile number, location, the report and '
            'its photos.',
        '• **Service providers** that run parts of ResQPulse for us, only '
            'for that purpose: Hostinger (our server and database); Google '
            '(Firebase Cloud Messaging for notifications, Gmail for emails '
            'with codes, Google Maps Platform for finding barangays and '
            'landmarks, and Gemini for the AI photo check); Semaphore and '
            'TextBee (text messages); and OpenStreetMap services (maps, place '
            'search and the OSRM route service).',
        '• **Government authorities**, when the law requires it, for '
            'example under a court order.',
        'Some of these providers keep information outside the Philippines. '
            'We remain responsible for it under Section 21 of the Data Privacy '
            'Act. We don\'t sell your information, and we don\'t use it for '
            'advertising.',
      ]),
      _LegalSection('How long we keep it', [
        '• **Your account** is kept while it is in use. If MDRRMO rejects '
            'a sign-up, the account and its ID photo are removed.',
        '• **SOS alerts, reports, evacuation records and the Audit Log** '
            'are government records. We keep them while they are needed for '
            'the response, follow-up and planning, and as long as records '
            'rules require (Republic Act No. 9470, the National Archives of '
            'the Philippines Act of 2007). Then we delete them or remove what '
            'identifies you.',
        '• **Codes** sent by text or email stop working after 10 minutes.',
      ]),
      _LegalSection('How we protect it', [
        '• Information travels over encrypted connections (HTTPS).',
        '• Passwords are stored hashed, so nobody can read them.',
        '• Only authorized staff and teams can see personal information, '
            'and what staff do in the web panel is recorded.',
        '• Codes and limits on wrong passwords protect accounts. Logging '
            'out removes your account from the phone.',
        '• If a data breach affects your information, we will tell the '
            'National Privacy Commission and you, as the law requires.',
      ]),
      _LegalSection('Your rights', [
        'Under the Data Privacy Act, you can:',
        '• be told how your information is used;',
        '• get a copy of your information, including in an electronic '
            'format you can reuse;',
        '• have wrong or incomplete information corrected (you can change '
            'many details yourself in Profile);',
        '• object to the use of your information, or ask us to stop, block '
            'or delete it, where the law allows;',
        '• withdraw your consent at any time. This doesn\'t undo what was '
            'done before, and records the law requires us to keep stay;',
        '• be paid damages if you are harmed by inaccurate or unlawfully '
            'used information;',
        '• complain to the National Privacy Commission (privacy.gov.ph).',
        'To use these rights: Call MDRRMO Rosales at #2441, or visit the '
            'MDRRMO office, and ask for the Data Protection Officer of the '
            'Municipality of Rosales. We may ask you to prove who you are '
            'first.',
      ]),
      _LegalSection('Children', [
        'You must be 18 or older to create an account, or have a parent or '
            'guardian agree to these documents with you. Anyone, of any age, '
            'can send an SOS in an emergency.',
      ]),
      _LegalSection('Changes to this policy', [
        'We will post changes in the apps and at '
            'resqpulse.com/privacy-policy, with the date at the top. If a '
            'change is important, we will ask you to agree again.',
      ]),
    ],
  ),
  _LegalDocument(
    doc: LegalDoc.terms,
    title: 'Terms and Conditions',
    path: 'terms',
    summary: 'The rules for using ResQPulse',
    intro: [
      'These Terms and Conditions are the rules for using ResQPulse, '
          'Resqponder and the MDRRMO web panel, which are run by MDRRMO '
          'Rosales. By creating an account or using them, you agree to these '
          'terms and to the Privacy Policy.',
      'If you don\'t agree, don\'t use the apps. In an emergency, you can '
          'always call MDRRMO Rosales at #2441 or 911.',
    ],
    sections: [
      _LegalSection('ResQPulse doesn\'t replace calling for help', [
        '• ResQPulse helps you reach MDRRMO, but it depends on your phone, '
            'your internet connection, GPS and our servers, which can fail or '
            'be slow.',
        '• We can\'t promise how fast help will arrive, or that every alert '
            'or report will get through. If a life is in danger, also call '
            'MDRRMO Rosales (#2441) or 911.',
        '• Alerts can arrive late or not at all, for example when your '
            'phone is off or offline, or notifications are turned off. Listen '
            'to official announcements too.',
      ]),
      _LegalSection('Your account', [
        '• Give true and complete information, including a valid ID that '
            'is really yours. MDRRMO may decline an account it can\'t verify.',
        '• Use one account per person.',
        '• Keep your password and codes private. You are responsible for '
            'what is done with your account. Tell MDRRMO if you think someone '
            'else is using it.',
        '• You must be 18 or older, or have a parent or guardian agree to '
            'these terms with you.',
      ]),
      _LegalSection('Use ResQPulse responsibly', [
        'Don\'t:',
        '• send false, prank or test SOS alerts or reports;',
        '• send photos that aren\'t of the emergency, or that are obscene '
            'or abusive;',
        '• share other people\'s personal details unless they are needed to '
            'get help;',
        '• pretend to be someone else, or use another person\'s account;',
        '• harass MDRRMO staff or responders;',
        '• try to break into, overload, copy or disrupt the apps or the '
            'server.',
        'MDRRMO may block an account that breaks these rules, and may '
            'report serious misuse, such as false emergency reports, to the '
            'authorities under the laws and ordinances that apply.',
      ]),
      _LegalSection('What you send us', [
        'You keep your rights to the photos and words you send. You allow '
            'MDRRMO Rosales to use them to respond to emergencies, to keep '
            'records, and for training and planning. When we use them outside '
            'MDRRMO, we remove what identifies people. Only send what you have '
            'the right to share.',
      ]),
      _LegalSection('For response teams and MDRRMO staff', [
        '• Only authorized MDRRMO personnel and partner response teams may '
            'use Resqponder and the web panel.',
        '• Keep a shared agency account within the agency. If someone '
            'leaves, ask MDRRMO to change the password.',
        '• Residents\' information is confidential. Use it only for the '
            'response, don\'t copy or share it outside your work, and never '
            'post it online. Misusing it can be a crime under the Data Privacy '
            'Act.',
        '• What you do in the system is recorded.',
      ]),
      _LegalSection('Information in the apps', [
        '• Safety tips and first-aid steps are general guidance, not '
            'medical advice. In a medical emergency, call for help.',
        '• Hotlines, evacuation centers and maps are kept as up to date as '
            'we can, but they can change. Distances and travel times are '
            'estimates.',
        '• The AI photo check can be wrong. MDRRMO staff decide what '
            'happens with a report.',
      ]),
      _LegalSection('Changes and availability', [
        '• The apps are free. We may change, pause or stop them, for '
            'example for maintenance.',
        '• We may update these terms. We will show the date at the top, '
            'and ask you to agree again if a change is important.',
      ]),
      _LegalSection('Responsibility', [
        'We work to keep ResQPulse accurate and running, but we provide it '
            'as it is. As far as Philippine law allows, MDRRMO Rosales is not '
            'responsible for losses caused by delays, outages, wrong '
            'information from users, or problems with your phone or internet '
            'connection. Nothing in these terms takes away rights the law '
            'gives you.',
      ]),
      _LegalSection('Law that applies', [
        'These terms are governed by the laws of the Philippines.',
      ]),
      _LegalSection('Contact', [
        'Questions about these terms: call MDRRMO Rosales at #2441, or '
            'visit the MDRRMO office.',
      ]),
    ],
  ),
  _LegalDocument(
    doc: LegalDoc.cookies,
    title: 'Cookie Policy',
    path: 'cookie-policy',
    summary: 'What the apps and the website store on your device',
    intro: [
      'This Cookie Policy explains the small files and data ResQPulse '
          'stores on your phone or browser. We don\'t use cookies or similar '
          'tools for advertising, or to follow you across other websites or '
          'apps.',
    ],
    sections: [
      _LegalSection('On the MDRRMO web panel (resqpulse.com)', [
        'The web panel only uses what it needs to work, so it doesn\'t ask '
            'for cookie consent:',
        '• **Session cookie:** keeps you signed in while you use the '
            'panel. It ends when you sign out or your session expires.',
        '• **XSRF-TOKEN:** protects forms from being sent by other '
            'websites.',
        '• **"Remember me" cookie:** only if you tick Remember me. It '
            'keeps you signed in on that browser until you sign out.',
        '• **Browser storage** (localStorage and sessionStorage): small '
            'settings, such as which SOS alerts you have already seen and '
            'which tab you were on. They don\'t hold personal information.',
        'Some pages load maps from Google Maps, and fonts and code from '
            'Google Fonts and jsDelivr. These providers receive your internet '
            'address and may use their own cookies under their own policies.',
      ]),
      _LegalSection('In the ResQPulse and Resqponder apps', [
        'The apps don\'t use browser cookies. They keep on your phone:',
        '• your login and basic account details, so you stay logged in;',
        '• for guests, the name and mobile number entered for SOS, so you '
            'don\'t have to type them again;',
        '• your alerts and settings, such as cleared alerts;',
        '• a notification token from Firebase Cloud Messaging, so the '
            'phone can get alerts;',
        '• map pictures from OpenStreetMap, saved for a short time.',
        'Logging out removes your login and notification token from the '
            'phone.',
      ]),
      _LegalSection('Your choices', [
        '• **Website:** you can block or delete cookies in your browser\'s '
            'settings, but you can\'t sign in to the panel without the session '
            'cookie.',
        '• **Apps:** log out, or clear the app\'s storage in your phone\'s '
            'settings. Uninstalling the app removes everything it saved.',
      ]),
      _LegalSection('Contact', [
        'Questions: call MDRRMO Rosales at #2441, or visit the MDRRMO '
            'office.',
      ]),
    ],
  ),
  _LegalDocument(
    doc: LegalDoc.accessibility,
    title: 'Accessibility',
    path: 'accessibility',
    summary: 'How we make ResQPulse usable for everyone',
    intro: [
      'MDRRMO Rosales wants everyone, including persons with '
          'disabilities and older residents, to be able to use ResQPulse and '
          'to get help.',
    ],
    sections: [
      _LegalSection('What we do', [
        '• Text in the apps follows your phone\'s font size setting.',
        '• We check new and updated screens for buttons that are large '
            'enough to tap, strong color contrast, and labels that screen '
            'readers such as TalkBack can read.',
        '• Information isn\'t shown by color alone; there are words or '
            'icons too.',
        '• Documents like this one use headings that screen readers can '
            'jump between.',
        '• For the website, we aim to meet the Web Content Accessibility '
            'Guidelines (WCAG) 2.1 at level AA. The Philippines adopted WCAG '
            'for government websites in the Philippine Web Accessibility '
            'Policy (DICT).',
      ]),
      _LegalSection('What may still be hard to use', [
        '• Maps and taking a photo of your ID can be hard to use with a '
            'screen reader.',
        '• SOS works best with location turned on.',
        '• Some older screens haven\'t been fully checked yet. We are '
            'working through them.',
        'If any part of ResQPulse doesn\'t work for you, you never need the '
            'app to get help: call MDRRMO Rosales at #2441 or 911.',
      ]),
      _LegalSection('Tell us about a problem', [
        'If something is hard to use, call MDRRMO Rosales at #2441, or '
            'visit the MDRRMO office. Tell us which screen it was and what '
            'happened. We will help you another way and work on fixing it.',
        'We are guided by the Magna Carta for Persons with Disability '
            '(Republic Act No. 7277, as amended) and the Philippine Web '
            'Accessibility Policy.',
      ]),
    ],
  ),
];

/// Shown above the sign-up check box: what, why, how long, who, rights
/// (NPC Circular No. 2023-04). The full details are in the Privacy Policy.
const String kSignUpPrivacyNotice =
    'MDRRMO Rosales will use your name, address, contact details and '
    'ID photo to confirm that you live in Rosales, and your reports, '
    'photos and location to respond to emergencies. It is kept while '
    'your account is in use, and longer only where government records '
    'rules require it. You can ask MDRRMO to see, correct or delete it.';

/// The sign-up check box. It must be ticked by the resident (never
/// pre-ticked): consent has to be a clear action.
const String kSignUpConsent =
    'I agree to the Terms and Conditions and the Privacy Policy, '
    'including the use of my ID photo to verify my account. I\'m 18 or '
    'older, or my parent or guardian agrees.';
