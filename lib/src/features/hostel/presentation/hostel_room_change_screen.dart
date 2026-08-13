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
        leading: onBack != null ? BackButton(onPressed: onBack) : null,
        title: const Text('Request Room Change'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRoomChangeSheet(context),
        backgroundColor: Colors.purple.shade700,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('New Transfer Request'),
      ),
      body: requests.isEmpty
          ? const Center(child: Text('No room change requests submitted.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final r = requests[index];
                return _buildRequestCard(context, r);
              },
            ),
    );
  }

  Widget _buildRequestCard(BuildContext context, RoomChangeRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: ${request.reason}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                        const SnackBar(content: Text('Room Change Request submitted to Warden.')),
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
