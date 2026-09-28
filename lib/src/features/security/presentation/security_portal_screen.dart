import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../../scanner/presentation/scan_qr_screen.dart';
import '../data/security_gate_repository.dart';
import 'gate_movement_detail_screen.dart';
import 'gate_movement_tile.dart';
import 'gate_scan_result_sheet.dart';
import 'walk_in_visitor_screen.dart';

/// The gate desk: the whole app for an account whose job is the gate.
///
/// Two tabs and nothing else — Home (scan, manual code, walk-in visitors,
/// today's counts) and History (every movement, tap for detail). Whether a
/// pass may be used is decided by the server; this screen only reports it.
class SecurityPortalScreen extends StatefulWidget {
  const SecurityPortalScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.onSignOut,
    this.initialAction,
    this.scanner,
  });

  final UserSession session;
  final SecurityGateRepository repository;
  final VoidCallback onSignOut;
  final String? initialAction;

  /// Opens the camera and returns a scanned payload. Defaults to the app's
  /// QR scanner; tests substitute their own.
  final Future<String?> Function(BuildContext context)? scanner;

  @override
  State<SecurityPortalScreen> createState() => _SecurityPortalScreenState();
}

class _SecurityPortalScreenState extends State<SecurityPortalScreen> {
  final _manualCode = TextEditingController();
  var _direction = GateDirection.entry;
  var _checkpoint = 'Main gate';
  var _tab = 0;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = false;
  var _submitting = false;
  String? _error;
  GateActivity _activity = const GateActivity();
  List<SecurityGateMovement> _movements = const [];

  static const _pageSize = 50;
  static const _checkpoints = [
    'Main gate',
    'North gate',
    'Hostel gate',
    'Visitor gate',
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialAction == 'movement_logs' ? 1 : 0;
    _load();
  }

  @override
  void dispose() {
    _manualCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await widget.repository.activity();
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _movements = activity.movements;
        _hasMore = activity.movements.length >= _pageSize;
      });
    } on SecurityGateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gate activity could not be loaded.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _movements.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.activity(
        before: _movements.last.createdAt,
      );
      if (!mounted) return;
      final known = _movements.map((item) => item.id).toSet();
      setState(() {
        _movements = [
          ..._movements,
          ...page.movements.where((item) => !known.contains(item.id)),
        ];
        _hasMore = page.movements.length >= _pageSize;
      });
    } catch (_) {
      // Keep what is shown; the button stays for another try.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openScanner() async {
    if (_submitting) return;
    final scan =
        widget.scanner ?? (context) => openScanQr(context, title: 'Scan pass');
    final code = await scan(context);
    if (code == null || !mounted) return;
    await _submitCode(code);
  }

  Future<void> _submitManualCode() async {
    FocusScope.of(context).unfocus();
    final code = _manualCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      await GateScanResultSheet.show(
        context,
        kind: GateScanResultKind.rejected,
        title: 'Check the code',
        message: 'Enter the six-digit code shown on the pass.',
      );
      return;
    }
    await _submitCode(code);
  }

  Future<void> _submitCode(String code) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _GateResult result;
    try {
      final movement = await widget.repository.scan(
        qrPayload: code,
        direction: _direction,
        checkpoint: _checkpoint,
      );
      _manualCode.clear();
      HapticFeedback.mediumImpact();
      if (mounted) {
        _insert(movement);
        unawaited(_load());
      }
      result = _GateResult(
        GateScanResultKind.accepted,
        movement.direction == GateDirection.entry
            ? 'Gate-in recorded'
            : 'Gate-out recorded',
        movement.late
            ? 'Valid pass · returned after the pass window.'
            : 'Valid pass · ${movement.passTypeLabel}.',
        movement,
      );
    } on GateAlreadyScannedException catch (error) {
      _manualCode.clear();
      HapticFeedback.heavyImpact();
      result = _GateResult(
        GateScanResultKind.alreadyScanned,
        'Already scanned',
        error.message,
        error.previous,
      );
    } on SecurityGateException catch (error) {
      HapticFeedback.heavyImpact();
      result = _GateResult(
        GateScanResultKind.rejected,
        'Do not allow',
        error.message,
      );
    } catch (_) {
      result = const _GateResult(
        GateScanResultKind.rejected,
        'Not verified',
        'The pass could not be verified. Check the connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (mounted) await result.show(context);
  }

  void _insert(SecurityGateMovement movement) {
    setState(() {
      _movements = [
        movement,
        ..._movements.where((item) => item.id != movement.id),
      ];
    });
  }

  Future<void> _openWalkIn() async {
    final movement = await Navigator.of(context).push<SecurityGateMovement>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WalkInVisitorScreen(
          repository: widget.repository,
          checkpoint: _checkpoint,
        ),
      ),
    );
    if (movement == null || !mounted) return;
    _insert(movement);
    unawaited(_load());
    await GateScanResultSheet.show(
      context,
      kind: GateScanResultKind.accepted,
      title: 'Visitor gated in',
      message: 'Record the gate-out from Home when they leave.',
      movement: movement,
    );
  }

  Future<void> _visitorGateOut(VisitorOnCampus visitor) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _GateResult result;
    try {
      final movement = await widget.repository.visitorGateOut(
        visitorPassId: visitor.id,
        checkpoint: _checkpoint,
      );
      if (mounted) _insert(movement);
      result = _GateResult(
        GateScanResultKind.accepted,
        'Gate-out recorded',
        '${visitor.name} has left campus.',
        movement,
      );
    } on GateAlreadyScannedException catch (error) {
      result = _GateResult(
        GateScanResultKind.alreadyScanned,
        'Already scanned',
        error.message,
        error.previous,
      );
    } on SecurityGateException catch (error) {
      result = _GateResult(
        GateScanResultKind.rejected,
        'Gate-out not recorded',
        error.message,
      );
    } catch (_) {
      result = const _GateResult(
        GateScanResultKind.rejected,
        'Gate-out not recorded',
        'Check the connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    unawaited(_load());
    await result.show(context);
  }

  Future<void> _openDetail(SecurityGateMovement movement) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GateMovementDetailScreen(
          repository: widget.repository,
          movement: movement,
          checkpoint: _checkpoint,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final background = context.adaptive(light: p.surface, dark: p.canvas);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [_homeTab(context), _historyTab(context)],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? p.brandInk
                  : p.inkSecondary,
            ),
          ),
        ),
        child: NavigationBar(
          key: const ValueKey('security-nav'),
          height: 68,
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          indicatorColor: p.brandSoft,
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: [
            NavigationDestination(
              key: const ValueKey('security-nav-home'),
              icon: Icon(Icons.home_outlined, color: p.inkSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: p.brandInk),
              label: 'Home',
            ),
            NavigationDestination(
              key: const ValueKey('security-nav-history'),
              icon: Icon(Icons.history_rounded, color: p.inkSecondary),
              selectedIcon: Icon(Icons.history_rounded, color: p.brandInk),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Home

  Widget _homeTab(BuildContext context) {
    final p = context.palette;
    final firstName = widget.session.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    final visitors = _activity.visitorsOnCampus;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('security-home'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gate security',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.1,
                        letterSpacing: -0.6,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$firstName · $_checkpoint',
                      style: TextStyle(fontSize: 15, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              _accountMenu(context),
            ],
          ),
          const SizedBox(height: 20),
          _movementControls(context),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('security-scan-gatepass'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: p.brand,
              foregroundColor: p.onBrand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _submitting ? null : _openScanner,
            icon: _submitting
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.onBrand,
                    ),
                  )
                : const Icon(Icons.qr_code_scanner_rounded),
            label: Text(
              _submitting
                  ? 'Verifying…'
                  : 'Scan pass for ${_direction.label.toLowerCase()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('security-manual-code'),
            controller: _manualCode,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitManualCode(),
            decoration: InputDecoration(
              hintText: 'Or enter the 6-digit code',
              counterText: '',
              prefixIcon: const Icon(Icons.dialpad_rounded),
              suffixIcon: IconButton(
                tooltip: 'Verify code',
                onPressed: _submitting ? null : _submitManualCode,
                icon: Icon(Icons.arrow_forward_rounded, color: p.brandInk),
              ),
              filled: true,
              fillColor: p.surfaceSunken,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: p.brand, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _sectionTitle(context, 'Today'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context,
                  'Gate in',
                  _activity.entriesToday,
                  Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  context,
                  'Gate out',
                  _activity.exitsToday,
                  Icons.north_east_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  context,
                  'Visitors in',
                  visitors.length,
                  Icons.badge_outlined,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _notice(context, _error!, onRetry: _load),
          ],
          const SizedBox(height: 26),
          _walkInCard(context),
          if (visitors.isNotEmpty) ...[
            const SizedBox(height: 26),
            _sectionTitle(context, 'Visitors on campus'),
            const SizedBox(height: 10),
            ...visitors.map((visitor) => _visitorRow(context, visitor)),
          ],
          if (_movements.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: _sectionTitle(context, 'Recent scans')),
                TextButton(
                  onPressed: () => setState(() => _tab = 1),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final movement in _movements.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GateMovementTile(
                  movement: movement,
                  onTap: () => _openDetail(movement),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _accountMenu(BuildContext context) {
    final p = context.palette;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'sign_out') widget.onSignOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            widget.session.displayName,
            style: TextStyle(color: p.inkSecondary),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'sign_out',
          child: Text('Sign out'),
        ),
      ],
      child: GatePersonAvatar(
        name: widget.session.displayName,
        photoUrl: widget.session.photoUrl,
        size: 40,
      ),
    );
  }

  Widget _movementControls(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<GateDirection>(
              key: const ValueKey('security-direction'),
              segments: const [
                ButtonSegment(
                  value: GateDirection.entry,
                  label: Text('Gate in'),
                  icon: Icon(Icons.south_west_rounded),
                ),
                ButtonSegment(
                  value: GateDirection.exit,
                  label: Text('Gate out'),
                  icon: Icon(Icons.north_east_rounded),
                ),
              ],
              selected: {_direction},
              showSelectedIcon: false,
              onSelectionChanged: _submitting
                  ? null
                  : (value) => setState(() => _direction = value.first),
              style: ButtonStyle(
                minimumSize: WidgetStateProperty.all(const Size(0, 44)),
                side: WidgetStateProperty.all(BorderSide.none),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? p.brand
                      : Colors.transparent,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? p.onBrand
                      : p.inkSecondary,
                ),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: const ValueKey('security-checkpoint'),
            initialValue: _checkpoint,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            decoration: InputDecoration(
              labelText: 'Checkpoint',
              prefixIcon: const Icon(Icons.location_on_outlined),
              filled: true,
              fillColor: p.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
            items: _checkpoints
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(growable: false),
            onChanged: _submitting
                ? null
                : (value) {
                    if (value != null) setState(() => _checkpoint = value);
                  },
          ),
        ],
      ),
    );
  }

  Widget _walkInCard(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const ValueKey('security-walk-in'),
        borderRadius: BorderRadius.circular(18),
        onTap: _submitting ? null : _openWalkIn,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_add_alt_1_rounded, color: p.brandInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Register walk-in visitor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No pass? Record who they are and gate them in.',
                      style: TextStyle(fontSize: 13, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visitorRow(BuildContext context, VisitorOnCampus visitor) {
    final p = context.palette;
    final since = visitor.checkedInAt == null
        ? null
        : 'In since ${gateTime(visitor.checkedInAt!)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          GatePersonAvatar(name: visitor.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitor.name,
                  style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
                ),
                Text(
                  [
                    if (visitor.hostName.isNotEmpty) 'Meeting ${visitor.hostName}',
                    ?since,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('security-visitor-out-${visitor.id}'),
            onPressed: _submitting ? null : () => _visitorGateOut(visitor),
            child: const Text('Gate out'),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value, IconData icon) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.brandInk),
          const SizedBox(height: 10),
          Text(
            _loading && _activity.movements.isEmpty ? '–' : '$value',
            style: TextStyle(
              fontSize: 24,
              height: 1,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: TextStyle(
      fontSize: 19,
      letterSpacing: -0.2,
      fontWeight: FontWeight.w700,
      color: context.palette.ink,
    ),
  );

  Widget _notice(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
  }) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: p.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: p.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: p.ink, fontSize: 13)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- History

  Widget _historyTab(BuildContext context) {
    final p = context.palette;
    final children = <Widget>[
      Text(
        'History',
        style: TextStyle(
          fontSize: 30,
          height: 1.1,
          letterSpacing: -0.6,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Every gate movement, newest first.',
        style: TextStyle(fontSize: 15, color: p.inkSecondary),
      ),
      const SizedBox(height: 18),
    ];
    if (_loading && _movements.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(36),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (_error != null && _movements.isEmpty) {
      children.add(_notice(context, _error!, onRetry: _load));
    } else if (_movements.isEmpty) {
      children.add(
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: p.surfaceSunken,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 36, color: p.inkTertiary),
              const SizedBox(height: 10),
              Text(
                'No gate movements yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.inkSecondary),
              ),
            ],
          ),
        ),
      );
    } else {
      String? day;
      for (final movement in _movements) {
        final label = gateDayLabel(movement.createdAt);
        if (label != day) {
          day = label;
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, left: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.inkSecondary,
                ),
              ),
            ),
          );
        }
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GateMovementTile(
              movement: movement,
              onTap: () => _openDetail(movement),
            ),
          ),
        );
      }
      if (_hasMore) {
        children.add(
          Center(
            child: TextButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(_loadingMore ? 'Loading…' : 'Show earlier'),
            ),
          ),
        );
      }
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('security-history'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: children,
      ),
    );
  }
}


/// A scan's outcome, held until the busy state clears so the sheet never
/// opens over a spinning button.
class _GateResult {
  const _GateResult(this.kind, this.title, this.message, [this.movement]);

  final GateScanResultKind kind;
  final String title;
  final String message;
  final SecurityGateMovement? movement;

  Future<void> show(BuildContext context) => GateScanResultSheet.show(
    context,
    kind: kind,
    title: title,
    message: message,
    movement: movement,
  );
}
