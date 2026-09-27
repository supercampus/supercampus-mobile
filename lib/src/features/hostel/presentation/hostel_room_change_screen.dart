import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

class HostelRoomChangeScreen extends StatelessWidget {
  const HostelRoomChangeScreen({
    super.key,
    required this.requests,
    required this.repository,
    required this.onRefresh,
    this.onBack,
  });

  final List<RoomChangeRequest> requests;
  final HostelRepository repository;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: onBack != null ? 0 : null,
        leading: onBack != null ? BackButton(onPressed: onBack) : null,
        title: const Text('Request Room Change'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        children: [
          Text(
            'Change your room',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell the warden your preference and track every decision.',
            style: TextStyle(color: context.palette.inkSecondary),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openRoomChangeSheet(context),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Start room-change request'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Requests',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${requests.length}',
                style: TextStyle(color: context.palette.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (requests.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No room-change requests yet.',
                  style: TextStyle(color: context.palette.inkSecondary),
                ),
              ),
            )
          else
            ...requests.map((request) => _buildRequestCard(context, request)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, RoomChangeRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.adaptive(light: Colors.purple.shade50, dark: Colors.purple.withValues(alpha: 0.18)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.adaptive(light: Colors.purple.shade800, dark: Colors.purple.shade200),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${request.currentRoom}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'Preferred Target: ${request.preferredHostel}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: context.palette.brandInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: ${request.reason}',
              style: TextStyle(color: context.palette.inkSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoomChangeSheet(BuildContext context) {
    final prefCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request Room Change',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: prefCtrl,
                decoration: const InputDecoration(
                  labelText: 'Preferred Hostel / Block / Room Type',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for Transfer',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (prefCtrl.text.trim().isEmpty) return;
                    await repository.requestRoomChange(
                      reason: reasonCtrl.text.trim(),
                      preferredHostel: prefCtrl.text.trim(),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Room Change Request submitted to Warden.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Submit Transfer Request'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
