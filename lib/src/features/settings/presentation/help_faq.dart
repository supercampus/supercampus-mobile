import 'package:flutter/material.dart';

/// Short answers about how this app actually works. Anything the institution
/// decides (amounts, approvers, timings) points to the Ask for help form
/// rather than stating a policy.
class FaqTopic {
  const FaqTopic({
    required this.title,
    required this.icon,
    required this.categoryKey,
    required this.entries,
  });

  final String title;
  final IconData icon;

  /// The help-request category that fits this topic.
  final String categoryKey;
  final List<FaqEntry> entries;
}

class FaqEntry {
  const FaqEntry(this.question, this.answer);

  final String question;
  final String answer;

  bool matches(String query) =>
      question.toLowerCase().contains(query) ||
      answer.toLowerCase().contains(query);
}

const faqTopics = <FaqTopic>[
  FaqTopic(
    title: 'Fees & payments',
    icon: Icons.receipt_long_outlined,
    categoryKey: 'fees',
    entries: [
      FaqEntry(
        'Where can I see what I owe?',
        'Open Tuition Fee. Your fee account shows the outstanding amount, '
            'with what was assigned, paid and waived, followed by your '
            'assigned fees and any fines.',
      ),
      FaqEntry(
        'How do I pay my fees?',
        'Tap Pay now in Tuition Fee to open Razorpay’s secure checkout. If the '
            'app says checkout is available in the web portal, sign in to the '
            'SuperCampus web portal in a browser and pay there.',
      ),
      FaqEntry(
        'Where are my receipts?',
        'In Tuition Fee under Payment history & receipts. Tap the download '
            'icon next to a payment to save its receipt.',
      ),
      FaqEntry(
        'An amount, fine or waiver looks wrong.',
        'Fees, fines and waivers are set by your institution. Ask via the '
            'form below and choose Fees & payments.',
      ),
    ],
  ),
  FaqTopic(
    title: 'Hostel & mess',
    icon: Icons.bed_outlined,
    categoryKey: 'hostel',
    entries: [
      FaqEntry(
        'How do I get my meal pass?',
        'Open Hostel → Mess & meals. Each meal has its own QR pass: tap Show '
            'and present it at the mess. A pass is marked Used or Expired '
            'afterwards.',
      ),
      FaqEntry(
        'Why can’t I see any meal passes?',
        'Meal passes appear once your hostel fee has been marked paid; until '
            'then you’ll see that payment verification is pending. Meal passes '
            'are for hostellers only. Meal times and whether the mess is open '
            'are set by your institution.',
      ),
      FaqEntry(
        'How do I report a problem in my room?',
        'Open Hostel → Report an issue. From the hostel home you can also '
            'request a room change, register visitors, or start vacating.',
      ),
    ],
  ),
  FaqTopic(
    title: 'Gatepass',
    icon: Icons.qr_code_2_rounded,
    categoryKey: 'gatepass',
    entries: [
      FaqEntry(
        'How do I request a pass?',
        'Open Gatepass. Everyone can Apply leave pass; hostellers can also '
            'Apply outpass. Fill in the details and tap Submit for approval.',
      ),
      FaqEntry(
        'Who approves my request?',
        'It depends on your institution — a request can need parent, warden, '
            'advisor/HOD or principal approval. Gatepass shows its status, and '
            'you can cancel it while it is still pending.',
      ),
      FaqEntry(
        'How do I use an approved pass at the gate?',
        'Show the pass QR to security. If it can’t be scanned, read out the '
            'six-digit code shown under the QR.',
      ),
      FaqEntry(
        'Why does my daily gate QR say it has expired?',
        'The daily Gate-in QR only works inside the campus boundary. Turn on '
            'location and open it again when you are on campus.',
      ),
    ],
  ),
  FaqTopic(
    title: 'Library',
    icon: Icons.local_library_outlined,
    categoryKey: 'library',
    entries: [
      FaqEntry(
        'How do I borrow a book?',
        'Open Library, find the book and send a borrow request. It waits for '
            'the librarian’s approval, then shows its due date under My '
            'borrowed books.',
      ),
      FaqEntry(
        'Can I renew a book?',
        'Renew appears on an approved loan that isn’t overdue. Overdue loans '
            'show the days late and any fine.',
      ),
      FaqEntry(
        'How do I book a visit slot?',
        'Tap Book a visit slot, pick a date and time, then Confirm Booking. '
            'Show its QR at the library to check in; you can also cancel or '
            'check out early.',
      ),
    ],
  ),
  FaqTopic(
    title: 'Attendance, marks & timetable',
    icon: Icons.school_outlined,
    categoryKey: 'academics',
    entries: [
      FaqEntry(
        'Where can I see my attendance?',
        'Open Academics. Overall attendance counts present, absent, OD and '
            'leave. Attendance history shows each day on a calendar — tap a '
            'day for the subject, staff and period.',
      ),
      FaqEntry(
        'Where are my marks and timetable?',
        'In Academics: Marks and results groups semester examinations, '
            'internal assessments and other tests, and Class Timetable shows '
            'your weekly schedule. “No marks published yet” means your '
            'department hasn’t released them.',
      ),
      FaqEntry(
        'My attendance or marks look wrong.',
        'These are recorded by your faculty. Ask via the form below and '
            'choose Attendance, marks & timetable.',
      ),
    ],
  ),
  FaqTopic(
    title: 'Canteen, wallet & PIN',
    icon: Icons.account_balance_wallet_outlined,
    categoryKey: 'canteen',
    entries: [
      FaqEntry(
        'Why do I have more than one wallet balance?',
        'Each shop — canteen, stationery, laundry — keeps its own wallet '
            'balance, and orders are paid from that shop’s wallet.',
      ),
      FaqEntry(
        'How do I add money to my wallet?',
        'Tap Top up in the shop’s wallet. If online top-up isn’t available, '
            'ask your institution’s accounts office to credit your wallet.',
      ),
      FaqEntry(
        'What is the transaction PIN?',
        'A 4-digit PIN that approves wallet payments. You create it the first '
            'time you pay, or in Settings → Transaction PIN.',
      ),
      FaqEntry(
        'I forgot my transaction PIN.',
        'Go to Settings → Transaction PIN and verify with your account '
            'password — or your recovery word, if you set one — then choose a '
            'new PIN.',
      ),
      FaqEntry(
        'Where do I collect my order?',
        'After paying, show the order’s QR at the counter.',
      ),
    ],
  ),
  FaqTopic(
    title: 'Account & app',
    icon: Icons.person_outline_rounded,
    categoryKey: 'app',
    entries: [
      FaqEntry(
        'I forgot my password.',
        'On the sign-in screen tap Forgot password? to get a reset link by '
            'email. If you are signed in, go to Settings → Password → Forgot '
            'your current password?',
      ),
      FaqEntry(
        'How do I change my password?',
        'Settings → Password. Enter your current password, then the new one '
            'twice.',
      ),
      FaqEntry(
        'How do I change my photo or name?',
        'Your photo and profile details are managed by your institution. Ask '
            'via the form below to have them corrected.',
      ),
      FaqEntry(
        'How do I switch to dark mode?',
        'Settings → Appearance, then choose Light, Dark or System.',
      ),
      FaqEntry(
        'Where are my notifications?',
        'Tap Alerts. Mark all as read clears the list.',
      ),
    ],
  ),
];
