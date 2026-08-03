import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';
import 'widgets/gatepass_ui.dart';

class GatepassRequestsScreen extends StatelessWidget {
  const GatepassRequestsScreen({
    super.key,
    required this.requests,
    required this.onApply,
    required this.onCancel,
  });

  final List<GatepassRequest> requests;
  final VoidCallback onApply;
  final Future<void> Function(GatepassRequest request) onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              GatepassPageHeader(
                title: 'My requests',
                subtitle: 'Track approvals and past outpasses',
                trailing: IconButton.filled(
                  tooltip: 'Apply for outpass',
                  onPressed: onApply,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.gateBlue,
                  ),
                  icon: const Icon(Icons.add),
                ),
              ),
              const SizedBox(height: 20),
              if (requests.isEmpty)
                const GatepassSurface(
                  padding: EdgeInsets.symmetric(vertical: 42, horizontal: 20),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 36),
                      SizedBox(height: 10),
                      Text('No outpass requests yet'),
                    ],
                  ),
                )
              else
                for (final request in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RequestCard(request: request, onCancel: onCancel),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onCancel});

  final GatepassRequest request;
  final Future<void> Function(GatepassRequest request) onCancel;

  @override
  Widget build(BuildContext context) {
    return GatepassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.type.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ApprovalPill(status: request.status),
            ],
          ),
          const SizedBox(height: 7),
          Text('${request.id} • ${request.destination}'),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.logout, size: 18, color: AppColors.gateBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatShortDate(request.departureAt)}, ${formatTime(request.departureAt)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.login, size: 18, color: AppColors.gateMagenta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatShortDate(request.returnAt)}, ${formatTime(request.returnAt)}',
                ),
              ),
            ],
          ),
          if (request.approver != null) ...[
            const SizedBox(height: 12),
            Text('Reviewed by ${request.approver}'),
          ],
          if (request.reviewNote != null) ...[
            const SizedBox(height: 8),
            Text(
              request.reviewNote!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (request.status == ApprovalStatus.pending) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onCancel(request),
                child: const Text('Cancel request'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
