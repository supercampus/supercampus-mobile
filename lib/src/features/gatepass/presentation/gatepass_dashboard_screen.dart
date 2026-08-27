import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
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
  const _CampusStatusCard({required this.store});

  final GatepassStore store;

  @override
  Widget build(BuildContext context) {
    final location = store.mapLocation;
    final student = store.student;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 184,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (location != null)
              _CampusMap(location: location)
            else
              const DecoratedBox(
                decoration: BoxDecoration(gradient: gatepassGradient),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xCC111033)],
                  stops: [0.3, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: store.zone == CampusZone.inside
                            ? const Color(0xFF1BA765)
                            : const Color(0xFFE74C3C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      store.zone == CampusZone.unknown
                          ? 'Locating…'
                          : store.zone == CampusZone.outside
                          ? 'Outside campus'
                          : 'Live location',
                      style: const TextStyle(
                        color: Color(0xFF17152B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 17,
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.zone == CampusZone.inside
                              ? 'You are on campus'
                              : store.zone == CampusZone.outside
                              ? 'You are off campus'
                              : 'Finding your location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${student.rollNumber}  •  ${student.department}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (location != null)
                    const Icon(
                      Icons.verified,
                      color: AppColors.gateLime,
                      size: 21,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusMap extends StatelessWidget {
  const _CampusMap({required this.location});

  final CampusMapLocation location;

  @override
  Widget build(BuildContext context) {
    final studentPoint = LatLng(
      location.studentLatitude,
      location.studentLongitude,
    );
    final campusPoint = LatLng(
      location.campusLatitude,
      location.campusLongitude,
    );
    return FlutterMap(
      options: MapOptions(
        initialCenter: studentPoint,
        initialZoom: 17,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ai.supercampus.mobile',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: campusPoint,
              radius: location.radiusMetres,
              useRadiusInMeter: true,
              color: const Color(0x332D20FF),
              borderColor: const Color(0xFF3424F5),
              borderStrokeWidth: 2,
            ),
            if (location.accuracyMetres > 0)
              CircleMarker(
                point: studentPoint,
                radius: location.accuracyMetres,
                useRadiusInMeter: true,
                color: const Color(0x223427FF),
                borderColor: const Color(0x663427FF),
                borderStrokeWidth: 1,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: studentPoint,
              width: 42,
              height: 42,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3424F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle, color: Colors.white),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          popupInitialDisplayDuration: Duration.zero,
        ),
      ],
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
