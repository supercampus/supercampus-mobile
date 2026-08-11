import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/library_models.dart';
import '../data/mock_library_repository.dart';

class LibraryShell extends StatefulWidget {
  const LibraryShell({
    super.key,
    required this.session,
    required this.onExitModule,
  });

  final UserSession session;
  final VoidCallback onExitModule;

  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell> {
  final _repository = MockLibraryRepository();
  final _durations = const [30, 60, 120];
  final _times = const [30, 45, 0, 15];
  var _duration = 60;
  var _minute = 0;
  LibraryVisitPass? _pass;
  String? _error;

  DateTime get _selectedStart {
    final now = DateTime.now();
    var hour = now.hour + 1;
    if (hour > 20) hour = 10;
    return DateTime(now.year, now.month, now.day, hour, _minute);
  }

  void _book() {
    try {
      setState(() {
        _pass = _repository.book(start: _selectedStart, duration: _duration);
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _update(LibraryVisitPass Function() action) {
    try {
      setState(() {
        _pass = action();
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pass = _pass;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D357F),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Modules Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: widget.onExitModule,
        ),
        title: const Text('Library'),
      ),
      body: pass == null || pass.status == LibraryPassStatus.cancelled
          ? _bookingView()
          : _passView(pass),
    );
  }

  Widget _bookingView() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _HeroCard(session: widget.session),
      const SizedBox(height: 22),
      const Text(
        'VISIT LIBRARY',
        style: TextStyle(
          color: AppColors.muted,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Choose a duration',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: [
          for (final d in _durations)
            ButtonSegment(
              value: d,
              label: Text(d == 60 ? '1 Hour' : '$d Minutes'),
            ),
        ],
        selected: {_duration},
        onSelectionChanged: (value) => setState(() => _duration = value.first),
      ),
      const SizedBox(height: 24),
      const Text(
        'Choose a start time',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final minute in _times) _timeChoice(minute)],
      ),
      const SizedBox(height: 20),
      _Availability(available: _repository.availableAt(_selectedStart)),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text('$_error', style: TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _book,
        icon: const Icon(Icons.qr_code_2),
        label: const Text('Book and generate QR pass'),
      ),
    ],
  );

  Widget _timeChoice(int minute) {
    final start = _selectedStart;
    final selected = _minute == minute;
    return ChoiceChip(
      selected: selected,
      label: Text(
        DateFormat('h:mm a').format(
          DateTime(start.year, start.month, start.day, start.hour, minute),
        ),
      ),
      onSelected: (_) => setState(() => _minute = minute),
    );
  }

  Widget _passView(LibraryVisitPass pass) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        children: [
          const Icon(Icons.local_library_outlined, color: Color(0xFF6D357F)),
          const SizedBox(width: 10),
          const Text(
            'Central Library',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'LIBRARY PASS',
                style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              QrImageView(data: pass.qrToken, size: 190),
              const SizedBox(height: 12),
              Text(
                pass.id,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${DateFormat('h:mm a').format(pass.start)} → ${DateFormat('h:mm a').format(pass.end)}',
              ),
              const SizedBox(height: 12),
              Chip(label: Text(pass.status.label)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (pass.status == LibraryPassStatus.active)
        FilledButton.icon(
          onPressed: () => _update(_repository.checkIn),
          icon: const Icon(Icons.login),
          label: const Text('Simulate check-in'),
        ),
      if (pass.status == LibraryPassStatus.inside)
        FilledButton.icon(
          onPressed: () => _update(_repository.checkOut),
          icon: const Icon(Icons.logout),
          label: const Text('Simulate check-out'),
        ),
      if (pass.status == LibraryPassStatus.active)
        OutlinedButton.icon(
          onPressed: () {
            _repository.cancel();
            setState(() => _pass = null);
          },
          icon: const Icon(Icons.close),
          label: const Text('Cancel visit'),
        ),
      if (pass.checkInAt != null)
        Text('Checked in: ${DateFormat('h:mm a').format(pass.checkInAt!)}'),
      if (pass.checkOutAt != null)
        Text('Checked out: ${DateFormat('h:mm a').format(pass.checkOutAt!)}'),
    ],
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.session});
  final UserSession session;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6D357F), Color(0xFF9B5BB0)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Icon(Icons.qr_code_2, color: Colors.white, size: 42),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your library, on your time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Book a time-bound QR pass for Central Library, ${session.displayName.split(' ').first}.',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Availability extends StatelessWidget {
  const _Availability({required this.available});
  final int available;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF6D357F).withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_outlined, color: Color(0xFF6D357F)),
        const SizedBox(width: 10),
        Text(
          '$available spots available',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        const Text(
          '487 / 500 booked',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
