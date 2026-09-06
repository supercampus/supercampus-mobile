import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../data/gatepass_models.dart';
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
    required this.onExitModule,
  });

  final GatepassStore store;
  final VoidCallback onApplyOutpass;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onOpenAccess;
  final VoidCallback onOpenRequests;
  final VoidCallback onInviteVisitor;
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFECEAFF),
                      child: Text(
                        store.student.initials,
                        style: const TextStyle(
                          color: AppColors.gateBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ModuleHomeButton(onPressed: onExitModule),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _CampusStatusCard(store: store),
              const SizedBox(height: 12),
              if (active != null) ...[
                _ActiveRequestCard(
                  request: active,
                  workflow: store.workflow,
                  onTap: onOpenRequests,
                ),
                const SizedBox(height: 12),
              ],
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
              const SizedBox(height: 6),
              GatepassSurface(
                child: Column(
                  children: store.movements
                      .take(2)
                      .map((movement) => _MovementRow(movement: movement))
                      .toList(),
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
  const _CampusStatusCard({required this.store});

  final GatepassStore store;

  @override
  Widget build(BuildContext context) {
    final inside = store.zone == CampusZone.inside;
    final outside = store.zone == CampusZone.outside;
    return GatepassSurface(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (inside ? const Color(0xFF168A5B) : AppColors.gateBlue)
                .withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            inside ? Icons.location_on_rounded : Icons.my_location_rounded,
            color: inside ? const Color(0xFF168A5B) : AppColors.gateBlue,
          ),
        ),
        title: Text(
          inside
              ? 'Campus location verified'
              : outside
              ? 'Outside campus'
              : 'Checking campus location',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          outside
              ? (store.dailyPassIssue ?? 'Gate-in QR is available on campus.')
              : '${store.student.rollNumber} · ${store.student.department}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: inside
            ? const Icon(Icons.verified_rounded, color: Color(0xFF168A5B))
            : null,
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
    final pass = store.dailyPass;
    final payload = pass?.qrPayload;
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
                    : () => _showGateQr(context, pass!),
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

  void _showGateQr(BuildContext context, DailyAccessPass pass) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGateQr(pass: pass),
      ),
    );
  }
}

class _FullScreenGateQr extends StatelessWidget {
  const _FullScreenGateQr({required this.pass});

  final DailyAccessPass pass;

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
                  child: QrImageView(data: pass.qrPayload, size: qrSize),
                ),
                const SizedBox(height: 28),
                const Text(
                  'DAILY GATE-IN ACCESS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
                if (pass.manualCode case final code?) ...[
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
    return GatepassSurface(
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
                    if (currentState != null) ...[
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
