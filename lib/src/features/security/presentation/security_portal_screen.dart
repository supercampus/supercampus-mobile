import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../../scanner/presentation/scan_qr_screen.dart';
import '../data/security_gate_repository.dart';

const _brandBlue = Color(0xFF1400FF);
const _brandPurple = Color(0xFFA600FF);
const _softPurple = Color(0xFF776CF5);

class SecurityPortalScreen extends StatefulWidget {
  const SecurityPortalScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.onSignOut,
  });

  final UserSession session;
  final SecurityGateRepository repository;
  final VoidCallback onSignOut;

  @override
  State<SecurityPortalScreen> createState() => _SecurityPortalScreenState();
}

class _SecurityPortalScreenState extends State<SecurityPortalScreen> {
  final _manualCode = TextEditingController();
  var _direction = GateDirection.entry;
  var _checkpoint = 'Main gate';
  var _selectedTab = 0;
  var _loadingHistory = true;
  var _submitting = false;
  String? _historyError;
  List<SecurityGateMovement> _movements = const [];

  static const _checkpoints = [
    'Main gate',
    'North gate',
    'Hostel gate',
    'Visitor gate',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _manualCode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final movements = await widget.repository.recentMovements();
      if (!mounted) return;
      setState(() => _movements = movements);
    } on SecurityGateException catch (error) {
      if (!mounted) return;
      setState(() => _historyError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyError = 'Recent gate scans could not be loaded.');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _openScanner() async {
    if (_submitting) return;
    final code = await openScanQr(context, title: 'Scan gatepass');
    if (code == null || !mounted) return;
    await _submitCode(code);
  }

  Future<void> _submitManualCode() async {
    FocusScope.of(context).unfocus();
    await _submitCode(_manualCode.text);
  }

  Future<void> _submitCode(String code) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final movement = await widget.repository.scan(
        qrPayload: code,
        direction: _direction,
        checkpoint: _checkpoint,
      );
      if (!mounted) return;
      _manualCode.clear();
      setState(() {
        _movements = [
          movement,
          ..._movements.where((item) => item.id != movement.id),
        ];
      });
      await _showAccepted(movement);
    } on SecurityGateException catch (error) {
      if (!mounted) return;
      await _showRejected(error.message);
    } catch (_) {
      if (!mounted) return;
      await _showRejected('The gatepass could not be verified. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showAccepted(SecurityGateMovement movement) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScanResultSheet(
        accepted: true,
        title: movement.direction == GateDirection.entry
            ? 'Gate-in recorded'
            : 'Gate-out recorded',
        message: [
          'Valid pass',
          if (movement.holderName != null) movement.holderName!,
          if (movement.passType != null) _passTypeLabel(movement.passType!),
          movement.checkpoint,
        ].join(' • '),
        movement: movement,
      ),
    );
  }

  Future<void> _showRejected(String message) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScanResultSheet(
        accepted: false,
        title: 'Do not allow movement',
        message: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.session.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gate security',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text(
              '$firstName • $_checkpoint',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh scans',
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedTab,
          children: [_scannerPage(), _historyPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (value) => setState(() => _selectedTab = value),
        indicatorColor: _softPurple.withValues(alpha: 0.16),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Scan history',
          ),
        ],
      ),
    );
  }

  Widget _scannerPage() {
    final today = _movements.where(_isToday).toList(growable: false);
    final entries = today
        .where((item) => item.direction == GateDirection.entry)
        .length;
    final exits = today.length - entries;
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brandBlue, _brandPurple],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _brandPurple.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verify campus movement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the movement, then scan the student or visitor gatepass.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                _directionSelector(),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _checkpoint,
                  dropdownColor: const Color(0xFF2D12B7),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Checkpoint',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                  items: _checkpoints
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(growable: false),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _checkpoint = value);
                          }
                        },
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('security-scan-gatepass'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    backgroundColor: Colors.white,
                    foregroundColor: _brandBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _submitting ? null : _openScanner,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    _submitting ? 'Verifying…' : 'Scan gatepass QR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _metric('Gate in', '$entries', Icons.login_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric('Gate out', '$exits', Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Manual verification',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use this only when the camera cannot read the QR.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualCode,
            enabled: !_submitting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitManualCode(),
            decoration: InputDecoration(
              hintText: 'Paste gatepass code',
              prefixIcon: const Icon(Icons.password_rounded),
              suffixIcon: IconButton(
                tooltip: 'Verify code',
                onPressed: _submitting ? null : _submitManualCode,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_movements.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Recent scans',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedTab = 1),
                  child: const Text('View all'),
                ),
              ],
            ),
            ..._movements.take(3).map(_movementTile),
          ],
        ],
      ),
    );
  }

  Widget _directionSelector() {
    return SegmentedButton<GateDirection>(
      segments: const [
        ButtonSegment(
          value: GateDirection.entry,
          label: Text('Gate in'),
          icon: Icon(Icons.login_rounded),
        ),
        ButtonSegment(
          value: GateDirection.exit,
          label: Text('Gate out'),
          icon: Icon(Icons.logout_rounded),
        ),
      ],
      selected: {_direction},
      onSelectionChanged: _submitting
          ? null
          : (value) => setState(() => _direction = value.first),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? _brandBlue : Colors.white,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white.withValues(alpha: 0.1),
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
      ),
      showSelectedIcon: false,
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _softPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _brandBlue),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(label, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyPage() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
        children: [
          Text(
            'Gate movement history',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            'Latest verified scans from every checkpoint.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          if (_loadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(color: _brandPurple),
              ),
            )
          else if (_historyError != null)
            _emptyState(
              Icons.cloud_off_outlined,
              _historyError!,
              action: TextButton(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            )
          else if (_movements.isEmpty)
            _emptyState(
              Icons.qr_code_2_rounded,
              'No gatepasses have been scanned yet.',
            )
          else
            ..._movements.map(_movementTile),
        ],
      ),
    );
  }

  Widget _movementTile(SecurityGateMovement movement) {
    final isEntry = movement.direction == GateDirection.entry;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isEntry ? _brandBlue : _brandPurple).withValues(
                alpha: .1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEntry ? Icons.login_rounded : Icons.logout_rounded,
              color: isEntry ? _brandBlue : _brandPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.direction.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  movement.checkpoint,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            _time(movement.createdAt),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message, {Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: _softPurple),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) action,
        ],
      ),
    );
  }

  bool _isToday(SecurityGateMovement value) {
    final now = DateTime.now();
    return value.createdAt.year == now.year &&
        value.createdAt.month == now.month &&
        value.createdAt.day == now.day;
  }

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  String _passTypeLabel(String value) => switch (value) {
    'daily_access' => 'Campus access',
    'leave_pass' => 'Leave pass',
    'outpass' => 'Outpass',
    'visitor' => 'Visitor pass',
    _ => value,
  };
}

class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({
    required this.accepted,
    required this.title,
    required this.message,
    this.movement,
  });

  final bool accepted;
  final String title;
  final String message;
  final SecurityGateMovement? movement;

  @override
  Widget build(BuildContext context) {
    final color = accepted ? _brandBlue : const Color(0xFFE53935);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                accepted ? Icons.verified_rounded : Icons.block_rounded,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            if (movement != null) ...[
              const SizedBox(height: 12),
              Text(
                'Reference ${movement!.id}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(accepted ? 'Scan next pass' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }
}
