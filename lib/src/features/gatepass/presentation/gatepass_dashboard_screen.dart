import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../data/gatepass_models.dart';
import '../data/gatepass_pass_phase.dart';
import '../data/gatepass_qr_selector.dart';
import 'widgets/gatepass_ui.dart';

class GatepassDashboardScreen extends StatelessWidget {
  const GatepassDashboardScreen({
    super.key,
    required this.store,
    required this.onApplyLeavePass,
    required this.onApplyOutpass,
    required this.onOpenAccess,
    required this.onOpenRequests,
    required this.onInviteVisitor,
    required this.onRetryLocation,
    required this.onExitModule,
    this.liveDailyPass,
    this.now,
  });

  final GatepassStore store;
  final VoidCallback onApplyOutpass;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onOpenAccess;
  final VoidCallback onOpenRequests;
  final VoidCallback onInviteVisitor;
  final VoidCallback onRetryLocation;
  final VoidCallback onExitModule;
  final ValueListenable<DailyAccessPass?>? liveDailyPass;

  /// Fixed clock for tests; the device clock otherwise.
  final DateTime? now;

  /// The pass that matters most right now: one in its window, then the next
  /// approved one, then one still waiting for approval. Expired, used, and
  /// declined passes never surface here.
  (GatepassRequest, GatepassPassPhase)? _currentPass(DateTime at) {
    (GatepassRequest, GatepassPassPhase)? best;
    int rank(GatepassPassPhase phase) => switch (phase) {
      GatepassPassPhase.active => 0,
      GatepassPassPhase.upcoming => 1,
      GatepassPassPhase.pending => 2,
      _ => 9,
    };
    for (final request in store.requests) {
      final phase = gatepassPassPhase(request, at: at);
      if (!phase.isCurrent) continue;
      if (best == null ||
          rank(phase) < rank(best.$2) ||
          (rank(phase) == rank(best.$2) &&
              request.departureAt.isBefore(best.$1.departureAt))) {
        best = (request, phase);
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentPass(now ?? DateTime.now());
    final isHosteller = store.student.residency == StudentResidency.hosteller;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Header(
                subtitle: '${store.student.residency.label} access',
                onBack: onExitModule,
              ),
              const SizedBox(height: 14),
              _CampusEntryCard(
                store: store,
                onRetry: onRetryLocation,
                liveDailyPass: liveDailyPass,
              ),
              const SizedBox(height: 14),
              _ApplyActions(
                isHosteller: isHosteller,
                onApplyLeavePass: onApplyLeavePass,
                onApplyOutpass: onApplyOutpass,
              ),
              if (current != null) ...[
                const SizedBox(height: 26),
                GatepassSectionHeader(
                  title: current.$2 == GatepassPassPhase.active
                      ? 'Active pass'
                      : current.$2 == GatepassPassPhase.upcoming
                      ? 'Next pass'
                      : 'Awaiting approval',
                ),
                _CurrentPassCard(
                  request: current.$1,
                  phase: current.$2,
                  workflow: store.workflow,
                  onTap: onOpenRequests,
                ),
              ],
              const SizedBox(height: 26),
              const GatepassSectionHeader(title: 'Quick actions'),
              GatepassSurface(
                child: Column(
                  children: [
                    _ActionRow(
                      icon: Icons.history_rounded,
                      label: 'Pass history',
                      detail: 'All your leave passes and outpasses',
                      onTap: onOpenRequests,
                    ),
                    Divider(
                      height: 1,
                      indent: 60,
                      color: context.palette.divider,
                    ),
                    _ActionRow(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Invite visitor',
                      detail: 'Pre-register a campus visit',
                      onTap: onInviteVisitor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              GatepassSectionHeader(
                title: 'Recent movement',
                trailing: TextButton(
                  onPressed: onOpenAccess,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('View all'),
                ),
              ),
              GatepassSurface(
                child: store.movements.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Text(
                            'No recent movement recorded.',
                            style: GatepassType.secondary(context),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final (index, movement)
                              in store.movements.take(2).indexed) ...[
                            if (index > 0)
                              Divider(
                                height: 1,
                                indent: 60,
                                color: context.palette.divider,
                              ),
                            _MovementRow(movement: movement),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back button with the title sitting right beside it, left-aligned.
class _Header extends StatelessWidget {
  const _Header({required this.subtitle, required this.onBack});

  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-8, 0),
          child: ModuleBackButton(onPressed: onBack),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(-8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Gatepass',
                    style: GatepassType.largeTitle(context),
                  ),
                ),
                Text(subtitle, style: GatepassType.footnote(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Today's campus entry QR, with where the device stands relative to the
/// campus fence explained in full and a way to check again.
class _CampusEntryCard extends StatelessWidget {
  const _CampusEntryCard({
    required this.store,
    required this.onRetry,
    this.liveDailyPass,
  });

  final GatepassStore store;
  final VoidCallback onRetry;
  final ValueListenable<DailyAccessPass?>? liveDailyPass;

  @override
  Widget build(BuildContext context) {
    final inside = store.zone == CampusZone.inside;
    final outside = store.zone == CampusZone.outside;
    final issue = store.dailyPassIssue;
    final failed = !inside && !outside && issue != null;
    final checking = !inside && !outside && !failed;
    final payload = gateInPassQr(store);
    final manualCode = store.dailyPass?.manualCode ?? '567890';

    final title = inside
        ? 'Campus location verified'
        : outside
        ? 'Outside campus'
        : failed
        ? 'Location check needs attention'
        : 'Checking campus location';
    final detail = inside
        ? 'Show this QR at the gate to enter campus. Tap it to open full screen.'
        : outside
        ? (issue ??
              'Your entry QR works once you are inside the campus boundary.')
        : failed
        ? issue
        : 'Confirming you are on campus. This takes a few seconds.';

    return GatepassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAMPUS ENTRY',
                      style: GatepassType.footnote(context).copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: context.palette.inkTertiary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LocationStatusIcon(
                          isChecking: checking,
                          isInside: inside,
                          needsAttention: failed || outside,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              title,
                              style: GatepassType.headline(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The QR keeps dark modules on a white quiet zone in both
              // themes so gate scanners read it reliably.
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => _FullScreenGateQr(
                        payload: payload,
                        manualCode: manualCode,
                        label: 'CAMPUS GATE-IN ACCESS',
                        liveDailyPass: liveDailyPass,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.adaptive(
                          light: const Color(0xFFE9E9EE),
                          dark: Colors.white,
                        ),
                      ),
                    ),
                    child: QrImageView(
                      data: payload,
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
          ),
          const SizedBox(height: 12),
          Text(detail, style: GatepassType.secondary(context)),
          if (failed || outside) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check location again'),
            ),
          ] else if (inside) ...[
            const SizedBox(height: 8),
            Text(
              '${store.student.rollNumber} · ${store.student.department}',
              style: GatepassType.footnote(
                context,
              ).copyWith(color: context.palette.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationStatusIcon extends StatefulWidget {
  const _LocationStatusIcon({
    required this.isChecking,
    required this.isInside,
    required this.needsAttention,
  });

  final bool isChecking;
  final bool isInside;
  final bool needsAttention;

  @override
  State<_LocationStatusIcon> createState() => _LocationStatusIconState();
}

class _LocationStatusIconState extends State<_LocationStatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isChecking) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _LocationStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isChecking && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isInside
        ? context.adaptive(
            light: const Color(0xFF168A5B),
            dark: const Color(0xFF6EE7B7),
          )
        : widget.needsAttention
        ? context.adaptive(
            light: const Color(0xFF8A5A00),
            dark: const Color(0xFFFCD34D),
          )
        : context.palette.brandInk;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animate = widget.isChecking && !reduceMotion;
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (animate)
            FadeTransition(
              opacity: Tween<double>(begin: .5, end: 0).animate(_controller),
              child: ScaleTransition(
                scale: Tween<double>(begin: .75, end: 1).animate(_controller),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                ),
              ),
            ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isInside
                  ? Icons.location_on_rounded
                  : widget.needsAttention
                  ? Icons.location_off_outlined
                  : Icons.my_location_rounded,
              size: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyActions extends StatelessWidget {
  const _ApplyActions({
    required this.isHosteller,
    required this.onApplyLeavePass,
    required this.onApplyOutpass,
  });

  final bool isHosteller;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onApplyOutpass;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const labelStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );
    final leave = FilledButton.tonalIcon(
      onPressed: onApplyLeavePass,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: shape,
        backgroundColor: context.adaptive(
          light: const Color(0xFFEFE8FE),
          dark: context.palette.brandSoft,
        ),
        foregroundColor: context.palette.brandInk,
      ),
      icon: const Icon(Icons.event_available_outlined, size: 20),
      label: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('Apply leave pass', style: labelStyle),
      ),
    );
    if (!isHosteller) return leave;
    return Row(
      children: [
        Expanded(child: leave),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onApplyOutpass,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: shape,
              backgroundColor: context.palette.brand,
              foregroundColor: context.palette.onBrand,
            ),
            icon: const Icon(Icons.directions_walk_rounded, size: 20),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Apply outpass', style: labelStyle),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullScreenGateQr extends StatelessWidget {
  const _FullScreenGateQr({
    required this.payload,
    required this.manualCode,
    required this.label,
    this.liveDailyPass,
  });

  final String payload;
  final String? manualCode;
  final String label;
  final ValueListenable<DailyAccessPass?>? liveDailyPass;

  @override
  Widget build(BuildContext context) {
    final qrSize = (MediaQuery.sizeOf(context).width - 92).clamp(200.0, 300.0);
    return Scaffold(
      backgroundColor: const Color(0xFF111014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111014),
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Gate-in QR',
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
        child: liveDailyPass == null
            ? _qrContent(context, payload, manualCode, qrSize)
            : ValueListenableBuilder<DailyAccessPass?>(
                valueListenable: liveDailyPass!,
                builder: (context, pass, _) => pass == null
                    ? _expiredContent()
                    : _qrContent(
                        context,
                        pass.qrPayload,
                        pass.manualCode,
                        qrSize,
                      ),
              ),
      ),
    );
  }

  Widget _qrContent(
    BuildContext context,
    String currentPayload,
    String? currentManualCode,
    double qrSize,
  ) => SingleChildScrollView(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                data: currentPayload,
                size: qrSize,
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
            const SizedBox(height: 28),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (currentManualCode case final code?) ...[
              const SizedBox(height: 8),
              Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Present this QR at security gate for campus entry (Gate-In)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _expiredContent() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 92),
          SizedBox(height: 20),
          Text(
            'QR expired',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You are outside the campus geofence. A new QR will appear after you enter again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

class _CurrentPassCard extends StatelessWidget {
  const _CurrentPassCard({
    required this.request,
    required this.phase,
    required this.workflow,
    required this.onTap,
  });

  final GatepassRequest request;
  final GatepassPassPhase phase;
  final GatepassWorkflowDefinition workflow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currentState = workflow.state(request.workflowState);
    final next =
        workflow.transition(request.workflowState, 'approve') ??
        workflow.transition(request.workflowState, 'verify') ??
        workflow.transition(request.workflowState, 'complete');
    final (tone, toneSoft) = gatepassTone(context, phase);
    final progress = [
      if (currentState != null &&
          currentState.label.toLowerCase() !=
              request.status.label.toLowerCase())
        currentState.label,
      if (next != null) 'Next: ${next.label}',
    ].join(' · ');
    final hint = switch (phase) {
      GatepassPassPhase.active => 'Tap to show the gate QR',
      GatepassPassPhase.upcoming =>
        'QR unlocks at ${gatepassMoment(request.departureAt)}',
      _ => null,
    };
    return GatepassPressable(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: toneSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              request.passKind == GatepassPassKind.leavePass
                  ? Icons.event_available_outlined
                  : Icons.directions_walk_rounded,
              size: 20,
              color: tone,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        request.type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GatepassType.headline(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PassPhaseChip(phase: phase),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${gatepassMoment(request.departureAt)} → ${gatepassTime(request.returnAt)}'
                  '${request.destination.trim().isEmpty ? '' : ' · ${request.destination.trim()}'}',
                  style: GatepassType.footnote(context),
                ),
                if (progress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    progress,
                    style: GatepassType.footnote(
                      context,
                    ).copyWith(color: p.inkTertiary),
                  ),
                ],
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: GatepassType.footnote(
                      context,
                    ).copyWith(color: p.brandInk),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: p.inkTertiary),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.adaptive(
                  light: const Color(0xFFEFE8FE),
                  dark: p.brandSoft,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: p.brandInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GatepassType.body(
                      context,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(detail, style: GatepassType.footnote(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final GateMovement movement;

  @override
  Widget build(BuildContext context) {
    final isEntry = movement.direction == MovementDirection.entry;
    final p = context.palette;
    final color = isEntry
        ? context.adaptive(
            light: const Color(0xFF087A4B),
            dark: const Color(0xFF6EE7B7),
          )
        : p.inkSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isEntry ? p.successSoft : p.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEntry ? Icons.login_rounded : Icons.logout_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEntry ? 'Campus entry' : 'Campus exit',
                  style: GatepassType.body(
                    context,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${movement.gate} • ${movement.method}',
                  style: GatepassType.footnote(context),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                gatepassTime(movement.recordedAt),
                style: GatepassType.body(
                  context,
                ).copyWith(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
              Text(
                gatepassDay(movement.recordedAt),
                style: GatepassType.footnote(
                  context,
                ).copyWith(color: p.inkTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
