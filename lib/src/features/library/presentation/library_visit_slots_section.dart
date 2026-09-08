import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/library_models.dart';
import '../data/library_repository.dart';
import 'library_book_slot_sheet.dart';
import 'library_qr_screen.dart';

/// The complete student visit-slot workflow embedded in the Library page.
class LibraryVisitSlotsSection extends StatefulWidget {
  const LibraryVisitSlotsSection({super.key, required this.repository});

  final LibraryRepository repository;

  @override
  State<LibraryVisitSlotsSection> createState() =>
      _LibraryVisitSlotsSectionState();
}

class _LibraryVisitSlotsSectionState extends State<LibraryVisitSlotsSection> {
  bool _loading = true;
  String? _error;

  List<LibraryVisitPass> get _activeBookings => widget.repository.bookings
      .where(
        (booking) =>
            booking.status == LibraryPassStatus.active ||
            booking.status == LibraryPassStatus.pending ||
            booking.status == LibraryPassStatus.approved ||
            booking.status == LibraryPassStatus.upcoming ||
            booking.status == LibraryPassStatus.inside,
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await widget.repository.loadBookings();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _bookSlot() async {
    final booking = await showModalBottomSheet<LibraryVisitPass>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .92,
        child: LibraryBookSlotSheet(repository: widget.repository),
      ),
    );
    if (booking == null || !mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Library visit slot booked.')));
  }

  Future<void> _showQr(LibraryVisitPass booking) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LibraryQrScreen(
          pass: booking,
          onCancel: widget.repository.cancelBooking,
          onEarlyCheckOut: widget.repository.earlyCheckOut,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _cancel(LibraryVisitPass booking) async {
    try {
      await widget.repository.cancelBooking(booking.id);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Library visit cancelled.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bookings = _activeBookings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Library visit slots',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (bookings.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.event_available_outlined, size: 17),
                label: Text('${bookings.length} active'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Reserve your reading-room time and access its QR pass here.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _bookSlot,
            icon: const Icon(Icons.add),
            label: const Text('Book a visit slot'),
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
        ] else if (_error != null) ...[
          const SizedBox(height: 12),
          _InlineMessage(
            icon: Icons.cloud_off_outlined,
            message: _error!,
            actionLabel: 'Retry',
            onAction: _load,
          ),
        ] else if (bookings.isEmpty) ...[
          const SizedBox(height: 12),
          const _InlineMessage(
            icon: Icons.event_available_outlined,
            message: 'No upcoming library visit is booked.',
          ),
        ] else ...[
          const SizedBox(height: 12),
          for (final booking in bookings)
            _VisitBookingCard(
              booking: booking,
              onShowQr: () => _showQr(booking),
              onCancel: () => _cancel(booking),
            ),
        ],
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _VisitBookingCard extends StatelessWidget {
  const _VisitBookingCard({
    required this.booking,
    required this.onShowQr,
    required this.onCancel,
  });

  final LibraryVisitPass booking;
  final VoidCallback onShowQr;
  final VoidCallback onCancel;

  bool get _canShowQr =>
      booking.status == LibraryPassStatus.active ||
      booking.status == LibraryPassStatus.approved ||
      booking.status == LibraryPassStatus.upcoming ||
      booking.status == LibraryPassStatus.inside;

  bool get _canCancel =>
      booking.status == LibraryPassStatus.active ||
      booking.status == LibraryPassStatus.pending ||
      booking.status == LibraryPassStatus.approved ||
      booking.status == LibraryPassStatus.upcoming;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('dd').format(booking.date),
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(booking.date).toUpperCase(),
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.zoneName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${DateFormat('h:mm a').format(booking.start)} – ${DateFormat('h:mm a').format(booking.end)}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(booking.status.label)),
              ],
            ),
            if (_canShowQr || _canCancel) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_canShowQr)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onShowQr,
                        icon: const Icon(Icons.qr_code_2, size: 18),
                        label: const Text('Show QR'),
                      ),
                    ),
                  if (_canShowQr && _canCancel) const SizedBox(width: 8),
                  if (_canCancel)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
