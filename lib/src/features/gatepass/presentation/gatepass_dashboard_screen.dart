import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';
import 'widgets/gatepass_ui.dart';

class GatepassDashboardScreen extends StatelessWidget {
  const GatepassDashboardScreen({
    super.key,
    required this.store,
    required this.onApplyOutpass,
    required this.onOpenAccess,
    required this.onOpenRequests,
    required this.onInviteVisitor,
    required this.onExitModule,
  });

  final GatepassStore store;
  final VoidCallback onApplyOutpass;
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
                leading: IconButton.filledTonal(
                  tooltip: 'Modules Home',
                  onPressed: onExitModule,
                  icon: const Icon(Icons.home),
                ),
                trailing: CircleAvatar(
                  backgroundColor: const Color(0xFFECEAFF),
                  child: Text(
                    store.student.initials,
                    style: const TextStyle(
                      color: AppColors.gateBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _CampusStatusCard(student: store.student),
              const SizedBox(height: 12),
              if (active != null) ...[
                _ActiveRequestCard(
                  request: active,
                  workflow: store.workflow,
                  onTap: onOpenRequests,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApplyOutpass,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gateBlue,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Apply outpass'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'Show access QR',
                    onPressed: onOpenAccess,
                    icon: const Icon(Icons.qr_code_2),
                  ),
                ],
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
  const _CampusStatusCard({required this.student});

  final GatepassStudent student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gatepassGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.isOnCampus
                      ? 'You are on campus'
                      : 'You are off campus',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${student.rollNumber}  •  ${student.department}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.gateLime,
              shape: BoxShape.circle,
            ),
          ),
        ],
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
