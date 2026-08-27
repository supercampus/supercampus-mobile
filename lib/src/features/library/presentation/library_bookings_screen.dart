import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/library_models.dart';
import '../data/mock_library_repository.dart';
import 'library_book_slot_sheet.dart';
import 'library_qr_screen.dart';

/// Landing page showing active library bookings with expandable detail cards.
class LibraryBookingsScreen extends StatefulWidget {
  const LibraryBookingsScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.onExitModule,
    this.initialAction,
  });

  final UserSession session;
  final MockLibraryRepository repository;
  final VoidCallback onExitModule;
  final String? initialAction;

  @override
  State<LibraryBookingsScreen> createState() => _LibraryBookingsScreenState();
}

class _LibraryBookingsScreenState extends State<LibraryBookingsScreen> {
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialAction());
  }

  void _openInitialAction() {
    if (!mounted) return;
    switch (widget.initialAction) {
      case 'book':
        _openBookSlot();
      case 'qr':
        if (_activeBookings.isNotEmpty) {
          _openQr(_activeBookings.first);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book a library visit to create a QR pass.'),
            ),
          );
        }
      case 'history':
        _openHistory();
    }
  }

  /// Only active, upcoming, and inside (checked-in) bookings appear on the
  /// main feed. Completed, cancelled, and expired bookings live in History.
  List<LibraryVisitPass> get _activeBookings => widget.repository.bookings
      .where(
        (b) =>
            b.status == LibraryPassStatus.active ||
            b.status == LibraryPassStatus.upcoming ||
            b.status == LibraryPassStatus.inside,
      )
      .toList();

  List<LibraryVisitPass> get _historyBookings => widget.repository.bookings
      .where(
        (b) =>
            b.status == LibraryPassStatus.used ||
            b.status == LibraryPassStatus.cancelled ||
            b.status == LibraryPassStatus.expired,
      )
      .toList();

  void _openBookSlot() async {
    final result = await showModalBottomSheet<LibraryVisitPass>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: LibraryBookSlotSheet(repository: widget.repository),
      ),
    );
    if (result != null && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.id} booked successfully!')),
      );
    }
  }

  void _openQr(LibraryVisitPass pass) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LibraryQrScreen(
          pass: pass,
          onCancel: (id) {
            widget.repository.cancelBooking(id);
          },
          onEarlyCheckOut: (id) {
            widget.repository.earlyCheckOut(id);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _cancelBooking(String id) {
    widget.repository.cancelBooking(id);
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _BookingHistoryScreen(
          bookings: _historyBookings,
          onHome: () {
            Navigator.of(context).pop();
            widget.onExitModule();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBookings = _activeBookings;
    final historyCount = _historyBookings.length;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.gateBlue,
        foregroundColor: Colors.white,
        leading: ModuleBackButton(
          onPressed: widget.onExitModule,
          color: Colors.white,
        ),
        title: const Text('Library Bookings'),
        actions: [
          if (historyCount > 0)
            TextButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history, size: 18, color: Colors.white70),
              label: const Text(
                'History',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ModuleHomeButton(onPressed: widget.onExitModule, color: Colors.white),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // Top action button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openBookSlot,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gateBlue,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Book Slot'),
                    ),
                  ),
                ),

                // Active bookings list
                Expanded(
                  child: activeBookings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_library_outlined,
                                size: 56,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No active bookings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap "Book Slot" to reserve your spot.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white38
                                      : AppColors.muted,
                                ),
                              ),
                              if (historyCount > 0) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _openHistory,
                                  icon: const Icon(Icons.history, size: 18),
                                  label: Text(
                                    'View $historyCount past booking${historyCount == 1 ? '' : 's'}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          itemCount: activeBookings.length,
                          itemBuilder: (context, index) {
                            final pass = activeBookings[index];
                            return _BookingCard(
                              pass: pass,
                              isExpanded: _expandedId == pass.id,
                              showQrAction: true,
                              showCancelAction: true,
                              onTap: () {
                                setState(() {
                                  _expandedId = _expandedId == pass.id
                                      ? null
                                      : pass.id;
                                });
                              },
                              onShowQr: () => _openQr(pass),
                              onCancel: () => _cancelBooking(pass.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking History Screen
// ─────────────────────────────────────────────────────────────────────────────

class _BookingHistoryScreen extends StatelessWidget {
  const _BookingHistoryScreen({required this.bookings, required this.onHome});

  final List<LibraryVisitPass> bookings;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final completed = bookings
        .where((b) => b.status == LibraryPassStatus.used)
        .toList();
    final cancelled = bookings
        .where(
          (b) =>
              b.status == LibraryPassStatus.cancelled ||
              b.status == LibraryPassStatus.expired,
        )
        .toList();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.canvas,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D357F),
        foregroundColor: Colors.white,
        leading: ModuleBackButton(
          onPressed: () => Navigator.of(context).pop(),
          color: Colors.white,
        ),
        title: const Text('Booking History'),
        actions: [ModuleHomeButton(onPressed: onHome, color: Colors.white)],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: bookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 56,
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No booking history',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      // ── Completed section ──
                      if (completed.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.check_circle_outline,
                          label: 'Completed',
                          count: completed.length,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : AppColors.success,
                        ),
                        const SizedBox(height: 10),
                        for (final pass in completed) _HistoryCard(pass: pass),
                        const SizedBox(height: 22),
                      ],

                      // ── Cancelled section ──
                      if (cancelled.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.cancel_outlined,
                          label: 'Cancelled',
                          count: cancelled.length,
                          color: isDark
                              ? const Color(0xFFEF5350)
                              : const Color(0xFFB71C1C),
                        ),
                        const SizedBox(height: 10),
                        for (final pass in cancelled) _HistoryCard(pass: pass),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// A minimal history card — no QR actions, no check-in buttons.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.pass});

  final LibraryVisitPass pass;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF171717) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark ? Colors.white54 : AppColors.muted;
    final borderColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE1E5E3);
    final badgeColor = isDark
        ? pass.status.badgeColorDark
        : pass.status.badgeColor;
    final badgeBg = isDark
        ? pass.status.badgeBackgroundDark
        : pass.status.badgeBackground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Date column
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd').format(pass.date),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(pass.date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pass.zoneName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('HH:mm').format(pass.start)} – ${DateFormat('HH:mm').format(pass.end)}',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                pass.status.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Booking Card (used on the landing feed)
// ─────────────────────────────────────────────────────────────────────────────

/// A booking card with inline expandable detail area.
class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.pass,
    required this.isExpanded,
    required this.onTap,
    required this.onShowQr,
    required this.onCancel,
    this.showQrAction = true,
    this.showCancelAction = true,
  });

  final LibraryVisitPass pass;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onShowQr;
  final VoidCallback onCancel;
  final bool showQrAction;
  final bool showCancelAction;

  bool get _canShowQr =>
      showQrAction &&
      (pass.status == LibraryPassStatus.active ||
          pass.status == LibraryPassStatus.upcoming ||
          pass.status == LibraryPassStatus.inside);

  bool get _canCancel =>
      showCancelAction &&
      (pass.status == LibraryPassStatus.upcoming ||
          pass.status == LibraryPassStatus.active);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF171717) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark ? Colors.white54 : AppColors.muted;
    final borderColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE1E5E3);
    final badgeColor = isDark
        ? pass.status.badgeColorDark
        : pass.status.badgeColor;
    final badgeBg = isDark
        ? pass.status.badgeBackgroundDark
        : pass.status.badgeBackground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded
                ? const Color(0xFF6D357F).withValues(alpha: 0.4)
                : borderColor,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            // ── Minimal card (always visible) ──
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Date column
                    Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D357F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('dd').format(pass.date),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6D357F),
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(pass.date).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6D357F),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pass.zoneName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('HH:mm').format(pass.start)} – ${DateFormat('HH:mm').format(pass.end)}',
                            style: TextStyle(fontSize: 13, color: mutedColor),
                          ),
                        ],
                      ),
                    ),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pass.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 240),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded detail area (Layer 1) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 14),

                          // Seat / Zone
                          if (pass.seatNumber != null)
                            _DetailRow(
                              icon: Icons.event_seat_outlined,
                              label: pass.seatNumber!,
                              isDark: isDark,
                            ),
                          if (pass.description != null &&
                              pass.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _DetailRow(
                              icon: Icons.description_outlined,
                              label: pass.description!,
                              isDark: isDark,
                            ),
                          ],
                          const SizedBox(height: 10),

                          // Library rules
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: mutedColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Maintain silence. No food or drinks. Return books to the designated area.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mutedColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // QR action — only for active/upcoming/inside
                          if (_canShowQr)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: onShowQr,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF6D357F),
                                  minimumSize: const Size(0, 46),
                                ),
                                icon: const Icon(Icons.qr_code_2, size: 18),
                                label: const Text('Show Check-In QR'),
                              ),
                            ),

                          // Cancel action — only for upcoming/active
                          if (_canCancel) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: onCancel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB71C1C),
                                  side: const BorderSide(
                                    color: Color(0xFFB71C1C),
                                  ),
                                  minimumSize: const Size(0, 42),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Cancel Booking'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white54 : AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
