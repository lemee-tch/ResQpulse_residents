import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'phone_call.dart';

part 'legal_text.dart';

/// Privacy Policy, Terms and Conditions, Cookie Policy and Accessibility
/// (items 64–65): the screens that show them. This file is the same in the
/// ResQPulse and Resqponder apps; what the documents say is in each app's
/// legal_text.dart, because each app has its own (item 65). The website
/// shows both sets (App\Support\Legal on the server).

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
  Color accent = _legalAccent,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalScreen(doc: doc, accent: accent),
    ),
  );
}

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

  const LegalScreen({super.key, required this.doc, this.accent = _legalAccent});

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
      // Each app's own look (item 65): Resqponder's navy bar, or
      // ResQPulse's white one.
      appBar: AppBar(
        backgroundColor: _legalFilledAppBar ? accent : Colors.white,
        surfaceTintColor: _legalFilledAppBar ? accent : Colors.white,
        elevation: 0,
        systemOverlayStyle: _legalFilledAppBar
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          tooltip: 'Back',
          icon: _legalFilledAppBar
              ? const Icon(Icons.arrow_back, color: Colors.white)
              : const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          document.title,
          style: TextStyle(
            color: _legalFilledAppBar ? Colors.white : _ink,
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

  const LegalLinks({super.key, this.accent = _legalAccent});

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
    this.accent = _legalAccent,
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
