import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../data/gatepass_models.dart';
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
  });

  final GatepassStore store;
  final VoidCallback onApplyOutpass;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onOpenAccess;
  final VoidCallback onOpenRequests;
  final VoidCallback onInviteVisitor;
  final VoidCallback onRetryLocation;
  final VoidCallback onExitModule;

  @override
  Widget build(BuildContext context) {
    final active = store.requests
        .where(
          (request) =>
              request.status == ApprovalStatus.pending ||
              request.status == ApprovalStatus.approved,
        )
        .firstOrNull;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              GatepassPageHeader(
                title: 'Gatepass',
                subtitle: '${store.student.residency.label} access',
                leading: ModuleBackButton(onPressed: onExitModule),
                trailing: ModuleHomeButton(onPressed: onExitModule),
              ),
              const SizedBox(height: 20),
              _CampusStatusCard(store: store, onRetry: onRetryLocation),
              const SizedBox(height: 12),
              _PassActions(
                store: store,
                onApplyLeavePass: onApplyLeavePass,
                onApplyOutpass: onApplyOutpass,
              ),
              const SizedBox(height: 26),
              Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Invite visitor',
                      color: AppColors.gateMagenta,
                      onTap: onInviteVisitor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.history,
                      label: 'Pass history',
                      color: AppColors.gateLavender,
                      onTap: onOpenRequests,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              GatepassSurface(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent movement',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: onOpenAccess,
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    if (active != null) ...[
                      const SizedBox(height: 2),
                      _ActiveRequestCard(
                        request: active,
                        workflow: store.workflow,
                        onTap: onOpenRequests,
                      ),
                    ],
                    if (store.movements.isNotEmpty) ...[
                      if (active != null) const SizedBox(height: 10),
                      ...store.movements
                          .take(2)
                          .map((movement) => _MovementRow(movement: movement)),
                    ] else if (active == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(
                            'No recent movement or pass activity.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ),
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

class _CampusStatusCard extends StatelessWidget {
  const _CampusStatusCard({required this.store, required this.onRetry});

  final GatepassStore store;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final inside = store.zone == CampusZone.inside;
    final outside = store.zone == CampusZone.outside;
    final issue = store.dailyPassIssue;
    final failed = !inside && !outside && issue != null;
    return GatepassSurface(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: _LocationStatusIcon(
          isChecking: !inside && !outside && !failed,
          isInside: inside,
        ),
        title: Text(
          inside
              ? 'Campus location verified'
              : outside
              ? 'Outside campus'
              : failed
              ? 'Location check needs attention'
              : 'Checking campus location',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          outside
              ? (store.dailyPassIssue ?? 'Gate-in QR is available on campus.')
              : failed
              ? issue
              : '${store.student.rollNumber} · ${store.student.department}',
          maxLines: failed ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: inside
            ? const Icon(Icons.verified_rounded, color: Color(0xFF168A5B))
            : failed
            ? IconButton(
                tooltip: 'Retry location check',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              )
            : null,
      ),
    );
  }
}

class _LocationStatusIcon extends StatefulWidget {
  const _LocationStatusIcon({required this.isChecking, required this.isInside});

  final bool isChecking;
  final bool isInside;

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
        ? const Color(0xFF168A5B)
        : AppColors.gateBlue;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isChecking)
            FadeTransition(
              opacity: Tween<double>(begin: .55, end: 0).animate(_controller),
              child: ScaleTransition(
                scale: Tween<double>(begin: .72, end: 1).animate(_controller),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
              ),
            ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: RotationTransition(
              turns: widget.isChecking
                  ? _controller
                  : const AlwaysStoppedAnimation(0),
              child: Icon(
                widget.isInside
                    ? Icons.location_on_rounded
                    : Icons.my_location_rounded,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassActions extends StatelessWidget {
  const _PassActions({
    required this.store,
    required this.onApplyLeavePass,
    required this.onApplyOutpass,
  });

  final GatepassStore store;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onApplyOutpass;

  @override
  Widget build(BuildContext context) {
    final approvedPass = store.requests
        .where(
          (request) =>
              request.status == ApprovalStatus.approved &&
              request.qrPayload?.isNotEmpty == true &&
              request.returnAt.isAfter(DateTime.now()),
        )
        .firstOrNull;
    final dailyPass = store.dailyPass;
    final payload = gatepassCardQr(store);
    final manualCode = approvedPass?.manualCode ?? dailyPass?.manualCode;
    final qrLabel = approvedPass == null
        ? 'DAILY GATE-IN ACCESS'
        : approvedPass.type.label.toUpperCase();
    final isHosteller = store.student.residency == StudentResidency.hosteller;
    return SizedBox(
      height: isHosteller ? 134 : 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: FilledButton.icon(
                    onPressed: onApplyLeavePass,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEAEAEA),
                      foregroundColor: const Color(0xFF18171D),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 26),
                    label: const Text(
                      'Apply leave pass',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (isHosteller) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: FilledButton(
                      onPressed: onApplyOutpass,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gateBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Apply outpass',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: const Color(0xFFEAEAEA),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: payload == null || payload.isEmpty
                    ? null
                    : () => _showGateQr(
                        context,
                        payload,
                        manualCode: manualCode,
                        label: qrLabel,
                      ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: payload == null || payload.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded, size: 42),
                            SizedBox(height: 6),
                            Text(
                              'Gate-in QR\nnot ready',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        )
                      : QrImageView(
                          data: payload,
                          padding: EdgeInsets.zero,
                          eyeStyle: const QrEyeStyle(color: Color(0xFF151419)),
                          dataModuleStyle: const QrDataModuleStyle(
                            color: Color(0xFF151419),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGateQr(
    BuildContext context,
    String payload, {
    required String? manualCode,
    required String label,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGateQr(
          payload: payload,
          manualCode: manualCode,
          label: label,
        ),
      ),
    );
  }
}

class _FullScreenGateQr extends StatelessWidget {
  const _FullScreenGateQr({
    required this.payload,
    required this.manualCode,
    required this.label,
  });

  final String payload;
  final String? manualCode;
  final String label;

  @override
  Widget build(BuildContext context) {
    final qrSize = (MediaQuery.sizeOf(context).width - 92).clamp(200.0, 300.0);
    return Scaffold(
      backgroundColor: const Color(0xFF111014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111014),
        foregroundColor: Colors.white,
        title: const Text('Gate-in QR'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
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
                  child: QrImageView(data: payload, size: qrSize),
                ),
                const SizedBox(height: 28),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
                if (manualCode case final code?) ...[
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
                  'Present this code at the campus gate',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveRequestCard extends StatelessWidget {
  const _ActiveRequestCard({
    required this.request,
    required this.workflow,
    required this.onTap,
  });

  final GatepassRequest request;
  final GatepassWorkflowDefinition workflow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentState = workflow.state(request.workflowState);
    final next =
        workflow.transition(request.workflowState, 'approve') ??
        workflow.transition(request.workflowState, 'verify') ??
        workflow.transition(request.workflowState, 'complete');
    return Material(
      color: const Color(0xFFF7F3FF),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined, color: AppColors.gateBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.type.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatShortDate(request.departureAt)} • ${request.destination}',
                    ),
                    if (currentState != null &&
                        currentState.label.toLowerCase() !=
                            request.status.label.toLowerCase()) ...[
                      const SizedBox(height: 4),
                      Text(currentState.label),
                    ],
                    if (next != null) ...[
                      const SizedBox(height: 4),
                      Text('Next: ${next.label}'),
                    ],
                  ],
                ),
              ),
              ApprovalPill(status: request.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(
            isEntry ? Icons.login : Icons.logout,
            color: isEntry ? const Color(0xFF087A4B) : AppColors.gateMagenta,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEntry ? 'Campus entry' : 'Campus exit'),
                Text('${movement.gate} • ${movement.method}'),
              ],
            ),
          ),
          Text(formatTime(movement.recordedAt)),
        ],
      ),
    );
  }
}
