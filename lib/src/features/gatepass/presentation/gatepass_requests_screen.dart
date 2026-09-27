import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../data/gatepass_models.dart';
import '../data/gatepass_pass_phase.dart';
import 'widgets/gatepass_ui.dart';

/// Pass history: every leave pass and outpass, grouped by whether it can
/// still be used. A pass is only valid for its own window, so once its return
/// time has passed it shows as expired and never offers a QR again.
class GatepassRequestsScreen extends StatefulWidget {
  const GatepassRequestsScreen({
    super.key,
    required this.requests,
    required this.residency,
    required this.onApplyLeavePass,
    required this.onApplyOutpass,
    required this.onCancel,
    this.now,
  });

  final List<GatepassRequest> requests;
  final StudentResidency residency;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onApplyOutpass;
  final Future<void> Function(GatepassRequest request) onCancel;

  /// Fixed clock for tests. When null the screen uses the device clock and
  /// re-renders itself the moment a pass opens or expires.
  final DateTime? now;

  @override
  State<GatepassRequestsScreen> createState() => _GatepassRequestsScreenState();
}

class _GatepassRequestsScreenState extends State<GatepassRequestsScreen> {
  Timer? _boundaryTimer;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleBoundary();
  }

  @override
  void didUpdateWidget(covariant GatepassRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleBoundary();
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    super.dispose();
  }

  /// Wakes up exactly when the next pass window opens or closes, so an open
  /// screen never keeps showing a QR past its return time.
  void _scheduleBoundary() {
    _boundaryTimer?.cancel();
    if (widget.now != null) return;
    final now = DateTime.now();
    DateTime? next;
    for (final request in widget.requests) {
      for (final edge in [request.departureAt, request.returnAt]) {
        if (edge.isAfter(now) && (next == null || edge.isBefore(next))) {
          next = edge;
        }
      }
    }
    if (next == null) return;
    var wait = next.difference(now) + const Duration(seconds: 1);
    if (wait > const Duration(hours: 12)) wait = const Duration(hours: 12);
    _boundaryTimer = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      _scheduleBoundary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final active = <GatepassRequest>[];
    final upcoming = <GatepassRequest>[];
    final past = <GatepassRequest>[];
    for (final request in widget.requests) {
      switch (gatepassPassPhase(request, at: now)) {
        case GatepassPassPhase.active:
          active.add(request);
        case GatepassPassPhase.upcoming || GatepassPassPhase.pending:
          upcoming.add(request);
        case _:
          past.add(request);
      }
    }
    active.sort((a, b) => a.returnAt.compareTo(b.returnAt));
    upcoming.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    past.sort((a, b) => b.returnAt.compareTo(a.returnAt));

    Widget section(String title, List<GatepassRequest> items) => Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GatepassSectionHeader(title: title),
          for (final request in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PassCard(
                request: request,
                phase: gatepassPassPhase(request, at: now),
                onCancel: widget.onCancel,
              ),
            ),
        ],
      ),
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Your leave passes and outpasses',
                        style: GatepassType.secondary(context),
                      ),
                    ),
                  ),
                  _NewPassButton(
                    residency: widget.residency,
                    onApplyLeavePass: widget.onApplyLeavePass,
                    onApplyOutpass: widget.onApplyOutpass,
                  ),
                ],
              ),
              if (widget.requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 22),
                  child: _EmptyHistory(),
                )
              else ...[
                if (active.isNotEmpty) section('Active', active),
                if (upcoming.isNotEmpty) section('Upcoming', upcoming),
                if (past.isNotEmpty) section('Past', past),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPassButton extends StatelessWidget {
  const _NewPassButton({
    required this.residency,
    required this.onApplyLeavePass,
    required this.onApplyOutpass,
  });

  final StudentResidency residency;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onApplyOutpass;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<GatepassPassKind>(
      tooltip: 'Apply for a pass',
      position: PopupMenuPosition.under,
      onSelected: (kind) => kind == GatepassPassKind.leavePass
          ? onApplyLeavePass()
          : onApplyOutpass(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: GatepassPassKind.leavePass,
          child: Text('Apply leave pass'),
        ),
        if (residency == StudentResidency.hosteller)
          const PopupMenuItem(
            value: GatepassPassKind.outpass,
            child: Text('Apply hostel outpass'),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.adaptive(
            light: const Color(0xFFEFE8FE),
            dark: context.palette.brandSoft,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 20, color: context.palette.brandInk),
            const SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                color: context.palette.brandInk,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return GatepassSurface(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 34,
            color: context.palette.inkTertiary,
          ),
          const SizedBox(height: 12),
          Text('No passes yet', style: GatepassType.headline(context)),
          const SizedBox(height: 4),
          Text(
            'Leave passes and outpasses you apply for will appear here.',
            textAlign: TextAlign.center,
            style: GatepassType.secondary(context),
          ),
        ],
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({
    required this.request,
    required this.phase,
    required this.onCancel,
  });

  final GatepassRequest request;
  final GatepassPassPhase phase;
  final Future<void> Function(GatepassRequest request) onCancel;

  bool get _muted =>
      phase == GatepassPassPhase.expired ||
      phase == GatepassPassPhase.cancelled ||
      phase == GatepassPassPhase.completed ||
      phase == GatepassPassPhase.rejected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (tone, toneSoft) = gatepassTone(context, phase);
    final qrPayload = request.qrPayload;
    final showQr =
        phase == GatepassPassPhase.active &&
        qrPayload != null &&
        qrPayload.trim().isNotEmpty;
    final destination = request.destination.trim();
    return GatepassSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _muted ? p.surfaceMuted : toneSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  request.passKind == GatepassPassKind.leavePass
                      ? Icons.event_available_outlined
                      : Icons.directions_walk_rounded,
                  size: 20,
                  color: _muted ? p.inkTertiary : tone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.passKind.label} • ${request.type.label}',
                      style: GatepassType.headline(
                        context,
                      ).copyWith(color: _muted ? p.inkSecondary : p.ink),
                    ),
                    if (destination.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GatepassType.footnote(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PassPhaseChip(phase: phase),
            ],
          ),
          const SizedBox(height: 14),
          _PassWindow(request: request, muted: _muted),
          if (request.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              request.reason.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GatepassType.secondary(context),
            ),
          ],
          if (request.reviewNote case final note?) ...[
            const SizedBox(height: 10),
            _Note(icon: Icons.chat_bubble_outline_rounded, text: note),
          ],
          if (request.approver case final approver?) ...[
            const SizedBox(height: 8),
            Text(
              'Reviewed by $approver',
              style: GatepassType.footnote(context),
            ),
          ],
          ..._footer(context, showQr ? qrPayload : null),
        ],
      ),
    );
  }

  List<Widget> _footer(BuildContext context, String? qrPayload) {
    switch (phase) {
      case GatepassPassPhase.active:
        if (qrPayload == null) {
          return [
            const SizedBox(height: 12),
            _Note(
              icon: Icons.hourglass_empty_rounded,
              text: 'Approved. The gate QR will appear here once issued.',
            ),
          ];
        }
        return [
          const SizedBox(height: 14),
          Divider(height: 1, color: context.palette.divider),
          const SizedBox(height: 14),
          _ActiveQr(request: request, payload: qrPayload),
        ];
      case GatepassPassPhase.upcoming:
        return [
          const SizedBox(height: 12),
          _Note(
            icon: Icons.schedule_rounded,
            text:
                'Your gate QR unlocks at ${gatepassMoment(request.departureAt)}.',
          ),
        ];
      case GatepassPassPhase.pending:
        return [
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onCancel(request),
              child: const Text('Cancel request'),
            ),
          ),
        ];
      case GatepassPassPhase.expired:
        return [
          const SizedBox(height: 12),
          _Note(
            key: const ValueKey('request-expired-note'),
            icon: Icons.timer_off_outlined,
            text: request.status == ApprovalStatus.pending
                ? 'Not approved before ${gatepassMoment(request.returnAt)}. This request has lapsed.'
                : 'Expired at ${gatepassMoment(request.returnAt)}. Apply for a new pass to go out again.',
          ),
        ];
      case GatepassPassPhase.rejected:
        return [
          const SizedBox(height: 10),
          _Note(
            icon: Icons.block_rounded,
            text: request.workflowState == 'rejected'
                ? 'This request was rejected by an approver.'
                : 'This request was rejected.',
          ),
        ];
      case GatepassPassPhase.completed || GatepassPassPhase.cancelled:
        return const [];
    }
  }
}

class _PassWindow extends StatelessWidget {
  const _PassWindow({required this.request, required this.muted});

  final GatepassRequest request;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget end(String label, DateTime at, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: GatepassType.footnote(
            context,
          ).copyWith(color: p.inkTertiary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          gatepassTime(at),
          style: TextStyle(
            fontSize: 17,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: muted ? p.inkSecondary : p.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(gatepassDay(at), style: GatepassType.footnote(context)),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: end('Out', request.departureAt, CrossAxisAlignment.start),
          ),
          Icon(Icons.arrow_forward_rounded, size: 18, color: p.inkTertiary),
          Expanded(child: end('In', request.returnAt, CrossAxisAlignment.end)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: context.palette.inkTertiary),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GatepassType.footnote(context))),
      ],
    );
  }
}

class _ActiveQr extends StatelessWidget {
  const _ActiveQr({required this.request, required this.payload});

  final GatepassRequest request;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final code = gatepassSixDigitCode(request.manualCode, payload);
    final (tone, _) = gatepassTone(context, GatepassPassPhase.active);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_rounded, size: 18, color: tone),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Ready at the gate',
                      style: GatepassType.headline(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Valid until ${gatepassMoment(request.returnAt)}. Tap the QR to show it full screen.',
                style: GatepassType.footnote(context),
              ),
              const SizedBox(height: 10),
              Text(
                code,
                key: const ValueKey('request-qr-code'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: context.palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // The QR keeps dark modules on a white quiet zone in both themes so
        // gate scanners read it reliably.
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('request-qr-open'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => _RequestQrScreen(payload: payload, code: code),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: payload,
                size: 108,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: Color(0xFF151419),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF151419),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The six-digit fallback code security can type when a scan fails.
String gatepassSixDigitCode(String? manualCode, String payload) {
  final supplied = (manualCode ?? '').replaceAll(RegExp(r'\D'), '');
  if (supplied.isNotEmpty) {
    return supplied.length >= 6
        ? supplied.substring(supplied.length - 6)
        : supplied.padLeft(6, '0');
  }
  final digits = payload.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 6) return digits.substring(digits.length - 6);
  var hash = 0;
  for (final unit in payload.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return (hash % 1000000).toString().padLeft(6, '0');
}

class _RequestQrScreen extends StatelessWidget {
  const _RequestQrScreen({required this.payload, required this.code});

  final String payload;
  final String code;

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width - 72).clamp(230.0, 340.0);
    return Scaffold(
      backgroundColor: const Color(0xFF111014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111014),
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Gatepass QR',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: payload,
                    size: size,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Color(0xFF151419),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF151419),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  code,
                  key: const ValueKey('fullscreen-request-qr-code'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Present this gatepass at security',
                  style: TextStyle(color: Colors.white70, letterSpacing: -0.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
