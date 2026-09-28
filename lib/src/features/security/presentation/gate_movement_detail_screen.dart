import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/security_gate_repository.dart';
import 'gate_movement_tile.dart';
import 'gate_scan_result_sheet.dart';

/// Everything about one gate movement: who, the pass behind it, and the
/// pass's full in/out timeline. Pops `true` when it recorded a gate-out.
class GateMovementDetailScreen extends StatefulWidget {
  const GateMovementDetailScreen({
    super.key,
    required this.repository,
    required this.movement,
    required this.checkpoint,
  });

  final SecurityGateRepository repository;

  /// The list row that was tapped; shown while the full detail loads.
  final SecurityGateMovement movement;

  /// Where a gate-out recorded from here happens.
  final String checkpoint;

  @override
  State<GateMovementDetailScreen> createState() =>
      _GateMovementDetailScreenState();
}

class _GateMovementDetailScreenState extends State<GateMovementDetailScreen> {
  GateMovementDetail? _detail;
  String? _error;
  var _loading = true;
  var _recording = false;
  var _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository.movementDetail(widget.movement.id);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on SecurityGateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'This movement could not be loaded.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordGateOut(String visitorPassId) async {
    setState(() => _recording = true);
    try {
      final movement = await widget.repository.visitorGateOut(
        visitorPassId: visitorPassId,
        checkpoint: widget.checkpoint,
      );
      if (!mounted) return;
      _changed = true;
      await GateScanResultSheet.show(
        context,
        kind: GateScanResultKind.accepted,
        title: 'Gate-out recorded',
        message: '${movement.displayName} has left campus.',
        movement: movement,
      );
      await _load();
    } on GateAlreadyScannedException catch (error) {
      if (!mounted) return;
      await GateScanResultSheet.show(
        context,
        kind: GateScanResultKind.alreadyScanned,
        title: 'Already scanned',
        message: error.message,
        movement: error.previous,
      );
      await _load();
    } on SecurityGateException catch (error) {
      if (!mounted) return;
      await GateScanResultSheet.show(
        context,
        kind: GateScanResultKind.rejected,
        title: 'Gate-out not recorded',
        message: error.message,
      );
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final detail = _detail;
    final movement = detail?.movement ?? widget.movement;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: context.adaptive(light: p.surfaceSunken, dark: p.canvas),
        appBar: AppBar(
          backgroundColor: context.adaptive(light: p.surfaceSunken, dark: p.canvas),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: const Text(
            'Movement',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _header(context, movement, detail?.person),
              const SizedBox(height: 20),
              if (_loading && detail == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && detail == null)
                _errorCard(context)
              else if (detail != null) ..._sections(context, detail),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    SecurityGateMovement movement,
    GateMovementPerson? person,
  ) {
    final p = context.palette;
    final name = person?.name ?? movement.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GatePersonAvatar(
              name: name,
              photoUrl: person?.photoUrl ?? movement.photoUrl,
              size: 64,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    movement.passTypeLabel,
                    style: TextStyle(fontSize: 15, color: p.inkSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            GateDirectionPill(direction: movement.direction),
            const SizedBox(width: 8),
            Text(
              gateDateTime(movement.createdAt),
              style: TextStyle(fontSize: 13, color: p.inkSecondary),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _sections(BuildContext context, GateMovementDetail detail) {
    final movement = detail.movement;
    final pass = detail.pass;
    final person = detail.person;
    final visitorInside =
        movement.visitorPassId != null && pass?.state == 'checked_in';
    return [
      _GroupedSection(
        title: 'Scan',
        rows: [
          ('Direction', movement.direction.label),
          ('Time', gateDateTime(movement.createdAt)),
          ('Checkpoint', movement.checkpoint),
          if (movement.scannedByName != null)
            ('Scanned by', movement.scannedByName!),
          if (movement.method != null) ('Method', _methodLabel(movement.method!)),
        ],
      ),
      if (pass != null)
        _GroupedSection(
          title: 'Pass',
          rows: [
            ('Type', pass.typeLabel),
            if (pass.destination != null) ('Destination', pass.destination!),
            if (pass.reason != null) ('Reason', pass.reason!),
            if (pass.purpose != null) ('Purpose', pass.purpose!),
            if (pass.hostName != null) ('Meeting', pass.hostName!),
            if (pass.vehicleNumber != null) ('Vehicle', pass.vehicleNumber!),
            if (pass.idNote != null) ('ID note', pass.idNote!),
            if (pass.validFrom != null)
              ('Valid from', gateDateTime(pass.validFrom!)),
            if (pass.validUntil != null && pass.type != 'daily_access')
              ('Valid until', gateDateTime(pass.validUntil!)),
            if (pass.approvedBy != null && pass.type != 'walk_in')
              ('Approved by', pass.approvedBy!),
            if (pass.registeredBy != null && pass.type == 'walk_in')
              ('Registered by', pass.registeredBy!),
            if (pass.state != null) ('Status', _stateLabel(pass.state!)),
          ],
        ),
      if (person.rollNumber != null ||
          person.department != null ||
          person.email != null ||
          person.phone != null)
        _GroupedSection(
          title: 'Person',
          rows: [
            if (person.rollNumber != null) ('Roll number', person.rollNumber!),
            if (person.department != null) ('Department', person.department!),
            if (person.email != null) ('Email', person.email!),
            if (person.phone != null) ('Phone', person.phone!),
          ],
        ),
      if (detail.timeline.length > 1)
        _GroupedSection(
          title: 'Timeline',
          rows: [
            for (final item in detail.timeline)
              (
                item.direction.label,
                '${gateDateTime(item.createdAt)} · ${item.checkpoint}',
              ),
          ],
        ),
      if (visitorInside) ...[
        const SizedBox(height: 4),
        FilledButton.icon(
          key: const ValueKey('gate-detail-visitor-out'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: context.palette.brand,
            foregroundColor: context.palette.onBrand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _recording
              ? null
              : () => _recordGateOut(movement.visitorPassId!),
          icon: const Icon(Icons.north_east_rounded),
          label: Text(
            _recording ? 'Recording…' : 'Record gate-out',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ];
  }

  Widget _errorCard(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!, style: TextStyle(color: p.inkSecondary)),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    );
  }

  static String _methodLabel(String value) => switch (value) {
    'qr' => 'QR scan',
    'manual_code' => '6-digit code',
    'walk_in' => 'Walk-in registration',
    'manual' => 'Recorded by guard',
    _ => value,
  };

  static String _stateLabel(String value) => switch (value) {
    'approved' || 'sent' || 'active' => 'Approved',
    'completed' => 'Completed',
    'checked_in' => 'On campus',
    'checked_out' => 'Left campus',
    'cancelled' => 'Cancelled',
    'rejected' => 'Rejected',
    'expired' => 'Expired',
    final other => other.replaceAll('_', ' '),
  };
}

/// An inset grouped list, iOS Settings style: a quiet caption, then label /
/// value rows on one rounded surface.
class _GroupedSection extends StatelessWidget {
  const _GroupedSection({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
                color: p.inkSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 14, color: p.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 112,
                          child: Text(
                            rows[i].$1,
                            style: TextStyle(
                              fontSize: 14,
                              color: p.inkSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rows[i].$2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
