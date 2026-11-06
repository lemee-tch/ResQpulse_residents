part of 'legal.dart';

// The legal documents of ResQPulse, the residents' app (items 64–65).
// The website shows the same text (App\Support\Legal on the server);
// Resqponder has its own documents in its own legal_text.dart.
// When the text changes, change it here and on the server, and change
// kLegalVersion.

/// Version of the documents below.
/// Sent with the sign-up consent, so MDRRMO knows which version a
/// resident agreed to.
const String kLegalVersion = '2026-11-06';

/// Shown at the top of each document.
const String kLegalUpdated = 'November 6, 2026';

/// This app's color for the documents' links and buttons.
const Color _legalAccent = Color(0xFF1A3A8F);

/// A navy app bar like the rest of the app (true), or a white one.
const bool _legalFilledAppBar = false;

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
      'It covers the ResQPulse app and the resqpulse.com website, '
          'including the MDRRMO web panel. Response teams have their own '
          'Privacy Policy in the Resqponder app and at '
          'resqpulse.com/resqponder/privacy-policy.',
    ],
    sections: [
      _LegalSection('Who we are', [
        'ResQPulse is run by the Municipal Disaster Risk Reduction and '
            'Management Office (MDRRMO) of the Municipality of Rosales, '
            'Pangasinan. MDRRMO Rosales decides how your information is '
            'used (it is the "personal information controller"). In this '
            'policy, "MDRRMO", "we" and "us" mean MDRRMO Rosales.',
        '**Questions or requests:** Call MDRRMO Rosales at #2441, or '
            'visit the MDRRMO office, and ask for the Data Protection '
            'Officer of the Municipality of Rosales.',
      ]),
      _LegalSection('What we collect from you', [
        '• **Your account:** your first, middle and last name, suffix, '
            'mobile number, email (if you use one), password, and your '
            'address in Rosales (barangay, street and zone). Your password '
            'is stored scrambled (hashed), so nobody can read it, not even '
            'MDRRMO.',
        '• **Proof of residency:** a photo of a valid ID. The law '
            'treats government-issued IDs as sensitive personal '
            'information. We use it only to confirm that you live in '
            'Rosales.',
        '• **Your agreement:** when you agreed to these documents, and '
            'to which version.',
        '• **SOS alerts and reports:** the kind of emergency, what you '
            'write, the photos you take, your location (GPS coordinates and '
            'how accurate they are), the barangay and nearest landmark '
            'worked out from it, and the time.',
        '• **Guests:** if you send an SOS without an account, the name '
            'and mobile number you enter, with the details above.',
        '• **Your phone:** a notification token, so we can send you '
            'alerts, and the internet (IP) address that reaches our server.',
        '• **At evacuation centers:** MSWD teams may record your name, '
            'age, sex, barangay and contact number with the Resqponder app. '
            'Its Privacy Policy explains how.',
      ]),
      _LegalSection('What we collect from MDRRMO staff', [
        'For staff who use the web panel: their name, email, and a '
            'record of what each person does in the panel (the Audit Log), '
            'with the date and internet address.',
      ]),
      _LegalSection('How your location is used', [
        '• ResQPulse sends your location to MDRRMO only when you send '
            'an SOS or a report.',
        '• On Evacuation Centers, your location is used on your phone '
            'to show the nearest centers. It is not sent to us.',
        '• To show the address of a report, your phone looks up the '
            'place at your location with OpenStreetMap\'s search service '
            '(Nominatim).',
      ]),
      _LegalSection('Why we use your information', [
        '• To receive, check and respond to SOS alerts and reports, and '
            'to send the right responders.',
        '• To confirm that an account belongs to a resident of Rosales, '
            'and to keep accounts secure (codes and limits on wrong '
            'passwords).',
        '• To send disaster alerts, and updates about your reports.',
        '• To prevent and deal with misuse, such as false reports.',
        '• For disaster planning and statistics, using totals that '
            'don\'t identify anyone.',
        '• To keep the records the law requires.',
      ]),
      _LegalSection('Our legal basis', [
        'Under Sections 12 and 13 of the Data Privacy Act, we use your '
            'information because:',
        '• you agreed to it when you created your account, including '
            'specifically for your ID photo (Sections 12(a) and 13(a));',
        '• it is needed to protect someone\'s life and health in an '
            'emergency (Sections 12(d) and 13(c));',
        '• it is needed to respond to emergencies, keep public order '
            'and safety, and carry out MDRRMO\'s duties under the Philippine '
            'Disaster Risk Reduction and Management Act of 2010 (Republic '
            'Act No. 10121) (Sections 12(e) and 13(b));',
        '• the law requires it, for example to keep public records '
            '(Section 12(c)).',
      ]),
      _LegalSection('The AI photo check', [
        'When an SOS or a report includes a photo, our server may send '
            'the photo to Google\'s Gemini AI service to suggest what kind '
            'of emergency it shows. The suggestion is only a hint for '
            'MDRRMO staff and responders. A person always checks the report '
            'and decides what to do; the AI does not decide whether help is '
            'sent.',
      ]),
      _LegalSection('Who sees your information', [
        '• **MDRRMO Rosales staff** who handle reports and accounts.',
        '• **The response teams sent to help** (for example police, '
            'fire, rescue, health and social welfare teams), in the '
            'Resqponder app. They see what they need to respond: your name, '
            'mobile number, location, the report and its photos. They must '
            'keep it confidential.',
        '• **Service providers** that run parts of ResQPulse for us, '
            'only for that purpose: Hostinger (our server and database); '
            'Google (Firebase Cloud Messaging for notifications, Gmail for '
            'emails with codes, Google Maps Platform for finding barangays '
            'and landmarks, and Gemini for the AI photo check); Semaphore '
            'and TextBee (text messages); and OpenStreetMap (maps and place '
            'search).',
        '• **Government authorities**, when the law requires it, for '
            'example under a court order.',
        'Some of these providers keep information outside the '
            'Philippines. We remain responsible for it under Section 21 of '
            'the Data Privacy Act. We don\'t sell your information, and we '
            'don\'t use it for advertising.',
      ]),
      _LegalSection('How long we keep it', [
        '• **Your account** is kept while it is in use. If MDRRMO '
            'rejects a sign-up, the account and its ID photo are removed.',
        '• **SOS alerts, reports and the Audit Log** are government '
            'records. We keep them while they are needed for the response, '
            'follow-up and planning, and as long as records rules require '
            '(Republic Act No. 9470, the National Archives of the '
            'Philippines Act of 2007). Then we delete them or remove what '
            'identifies you.',
        '• **Codes** sent by text or email stop working after 10 '
            'minutes.',
      ]),
      _LegalSection('How we protect it', [
        '• Information travels over encrypted connections (HTTPS).',
        '• Passwords are stored hashed, so nobody can read them.',
        '• Only authorized staff and teams can see personal '
            'information, and what staff do in the web panel is recorded.',
        '• Codes and limits on wrong passwords protect accounts. '
            'Logging out removes your account from the phone.',
        '• If a data breach affects your information, we will tell the '
            'National Privacy Commission and you, as the law requires.',
      ]),
      _LegalSection('Your rights', [
        'Under the Data Privacy Act, you can:',
        '• be told how your information is used;',
        '• get a copy of your information, including in an electronic '
            'format you can reuse;',
        '• have wrong or incomplete information corrected (you can '
            'change many details yourself in Profile);',
        '• object to the use of your information, or ask us to stop, '
            'block or delete it, where the law allows;',
        '• withdraw your consent at any time. This doesn\'t undo what '
            'was done before, and records the law requires us to keep stay;',
        '• be paid damages if you are harmed by inaccurate or '
            'unlawfully used information;',
        '• complain to the National Privacy Commission (privacy.gov.ph).',
        'To use these rights: Call MDRRMO Rosales at #2441, or visit '
            'the MDRRMO office, and ask for the Data Protection Officer of '
            'the Municipality of Rosales. We may ask you to prove who you '
            'are first.',
      ]),
      _LegalSection('Children', [
        'You must be 18 or older to create an account, or have a parent '
            'or guardian agree to these documents with you. Anyone, of any '
            'age, can send an SOS in an emergency.',
      ]),
      _LegalSection('Changes to this policy', [
        'We will post changes in the app and at '
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
      'These Terms and Conditions are the rules for using the ResQPulse '
          'app and the resqpulse.com website, including the MDRRMO web '
          'panel, which are run by MDRRMO Rosales. By creating an account '
          'or using them, you agree to these terms and to the Privacy '
          'Policy. Response teams follow the Resqponder app\'s own terms.',
      'If you don\'t agree, don\'t use the app. In an emergency, you can '
          'always call MDRRMO Rosales at #2441 or 911.',
    ],
    sections: [
      _LegalSection('ResQPulse doesn\'t replace calling for help', [
        '• ResQPulse helps you reach MDRRMO, but it depends on your '
            'phone, your internet connection, GPS and our servers, which '
            'can fail or be slow.',
        '• We can\'t promise how fast help will arrive, or that every '
            'alert or report will get through. If a life is in danger, also '
            'call MDRRMO Rosales (#2441) or 911.',
        '• Alerts can arrive late or not at all, for example when your '
            'phone is off or offline, or notifications are turned off. '
            'Listen to official announcements too.',
      ]),
      _LegalSection('Your account', [
        '• Give true and complete information, including a valid ID '
            'that is really yours. MDRRMO may decline an account it can\'t '
            'verify.',
        '• Use one account per person.',
        '• Keep your password and codes private. You are responsible '
            'for what is done with your account. Tell MDRRMO if you think '
            'someone else is using it.',
        '• You must be 18 or older, or have a parent or guardian agree '
            'to these terms with you.',
      ]),
      _LegalSection('Use ResQPulse responsibly', [
        'Don\'t:',
        '• send false, prank or test SOS alerts or reports;',
        '• send photos that aren\'t of the emergency, or that are '
            'obscene or abusive;',
        '• share other people\'s personal details unless they are needed '
            'to get help;',
        '• pretend to be someone else, or use another person\'s account;',
        '• harass MDRRMO staff or responders;',
        '• try to break into, overload, copy or disrupt the app, the '
            'website or the server.',
        'MDRRMO may block an account that breaks these rules, and may '
            'report serious misuse, such as false emergency reports, to the '
            'authorities under the laws and ordinances that apply.',
      ]),
      _LegalSection('What you send us', [
        'You keep your rights to the photos and words you send. You '
            'allow MDRRMO Rosales to use them to respond to emergencies, to '
            'keep records, and for training and planning. When we use them '
            'outside MDRRMO, we remove what identifies people. Only send '
            'what you have the right to share.',
      ]),
      _LegalSection('For MDRRMO staff', [
        '• Only authorized MDRRMO Rosales staff may use the web panel.',
        '• Residents\' information is confidential. Use it only for your '
            'work, don\'t copy or share it outside it, and never post it '
            'online. Misusing it can be a crime under the Data Privacy Act.',
        '• What you do in the panel is recorded.',
      ]),
      _LegalSection('Information in the app', [
        '• Safety tips and first-aid steps are general guidance, not '
            'medical advice. In a medical emergency, call for help.',
        '• Hotlines, evacuation centers and maps are kept as up to date '
            'as we can, but they can change. Distances are estimates.',
        '• The AI photo check can be wrong. MDRRMO staff decide what '
            'happens with a report.',
      ]),
      _LegalSection('Changes and availability', [
        '• The app is free. We may change, pause or stop it, for '
            'example for maintenance.',
        '• We may update these terms. We will show the date at the top, '
            'and ask you to agree again if a change is important.',
      ]),
      _LegalSection('Responsibility', [
        'We work to keep ResQPulse accurate and running, but we provide '
            'it as it is. As far as Philippine law allows, MDRRMO Rosales '
            'is not responsible for losses caused by delays, outages, wrong '
            'information from users, or problems with your phone or '
            'internet connection. Nothing in these terms takes away rights '
            'the law gives you.',
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
    summary: 'What the app and the website store on your device',
    intro: [
      'This Cookie Policy explains the small files and data ResQPulse '
          'stores on your phone or browser. We don\'t use cookies or similar '
          'tools for advertising, or to follow you across other websites or '
          'apps.',
    ],
    sections: [
      _LegalSection('On the MDRRMO web panel (resqpulse.com)', [
        'The web panel only uses what it needs to work, so it doesn\'t '
            'ask for cookie consent:',
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
            'Google Fonts and jsDelivr. These providers receive your '
            'internet address and may use their own cookies under their own '
            'policies. The legal pages, like this one, load nothing from '
            'other websites.',
      ]),
      _LegalSection('In the ResQPulse app', [
        'The app doesn\'t use browser cookies. It keeps on your phone:',
        '• your login and basic account details, so you stay logged in;',
        '• for guests, the name and mobile number entered for SOS, so '
            'you don\'t have to type them again;',
        '• your alerts and settings, such as cleared alerts;',
        '• a notification token from Firebase Cloud Messaging, so the '
            'phone can get alerts.',
        'Map pictures from OpenStreetMap are only kept while the app is '
            'open. Logging out removes your login and notification token '
            'from the phone.',
      ]),
      _LegalSection('Your choices', [
        '• **Website:** you can block or delete cookies in your '
            'browser\'s settings, but you can\'t sign in to the panel without '
            'the session cookie.',
        '• **App:** log out, or clear the app\'s storage in your phone\'s '
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
          'disabilities and older residents, to be able to use ResQPulse '
          'and to get help.',
    ],
    sections: [
      _LegalSection('What we do', [
        '• Text in the app follows your phone\'s font size setting.',
        '• We check new and updated screens for buttons that are large '
            'enough to tap, strong color contrast, and labels that screen '
            'readers such as TalkBack can read.',
        '• Information isn\'t shown by color alone; there are words or '
            'icons too.',
        '• Documents like this one use headings that screen readers can '
            'jump between.',
        '• For the website, we aim to meet the Web Content '
            'Accessibility Guidelines (WCAG) 2.1 at level AA. The '
            'Philippines adopted WCAG for government websites in the '
            'Philippine Web Accessibility Policy (DICT).',
      ]),
      _LegalSection('What may still be hard to use', [
        '• Maps and taking a photo of your ID can be hard to use with a '
            'screen reader.',
        '• SOS works best with location turned on.',
        '• Some older screens haven\'t been fully checked yet. We are '
            'working through them.',
        'If any part of ResQPulse doesn\'t work for you, you never need '
            'the app to get help: call MDRRMO Rosales at #2441 or 911.',
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
    'MDRRMO Rosales will use your name, address, contact details and ID '
    'photo to confirm that you live in Rosales, and your reports, photos '
    'and location to respond to emergencies. It is kept while your account '
    'is in use, and longer only where government records rules require it. '
    'You can ask MDRRMO to see, correct or delete it.';

/// The sign-up check box. It must be ticked by the resident (never
/// pre-ticked): consent has to be a clear action.
const String kSignUpConsent =
    'I agree to the Terms and Conditions and the Privacy Policy, including '
    'the use of my ID photo to verify my account. I\'m 18 or older, or my '
    'parent or guardian agrees.';
