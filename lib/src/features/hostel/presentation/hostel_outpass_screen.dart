import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

class HostelOutpassScreen extends StatelessWidget {
  const HostelOutpassScreen({
    super.key,
    required this.outpasses,
    required this.repository,
    required this.onRefresh,
    this.onBack,
  });

  final List<HostelOutpass> outpasses;
  final HostelRepository repository;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null ? BackButton(onPressed: onBack) : null,
        title: const Text('Leave / Outpass System'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        children: [
          Text(
            'Plan your leave',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Submit the destination and return time. Approval and QR status stay together.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openApplyOutpassSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Request outpass'),
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
                '${outpasses.length}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (outpasses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No outpass requests yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...outpasses.map((outpass) => _buildOutpassCard(context, outpass)),
        ],
      ),
    );
  }

  Widget _buildOutpassCard(BuildContext context, HostelOutpass outpass) {
    final isApproved =
        outpass.status == OutpassStatus.approved ||
        outpass.status == OutpassStatus.active;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    outpass.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    outpass.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isApproved
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Destination: ${outpass.destination}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: ${outpass.reason}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeTile(
                    'Leaving Time',
                    _formatTime(outpass.leavingAt),
                    Icons.north_east,
                    Colors.orange.shade700,
                  ),
                ),
                Expanded(
                  child: _buildTimeTile(
                    'Expected Return',
                    _formatTime(outpass.expectedReturnAt),
                    Icons.south_west,
                    Colors.green.shade700,
                  ),
                ),
              ],
            ),
            if (isApproved) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openOutpassQrDialog(context, outpass),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show Gate Outpass QR'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTile(
    String title,
    String timeStr,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            Text(
              timeStr,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  void _openApplyOutpassSheet(BuildContext context) {
    final destCtrl = TextEditingController();
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
                'Apply Hostel Outpass / Leave',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: destCtrl,
                decoration: const InputDecoration(
                  labelText: 'Destination (e.g. City Mall, Home)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Exit'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (destCtrl.text.trim().isEmpty) return;
                    final now = DateTime.now();
                    await repository.requestOutpass(
                      leavingAt: now,
                      expectedReturnAt: now.add(const Duration(hours: 3)),
                      destination: destCtrl.text.trim(),
                      reason: reasonCtrl.text.trim().isEmpty
                          ? 'Personal'
                          : reasonCtrl.text.trim(),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Outpass submitted & auto-approved!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Submit Outpass Request'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openOutpassQrDialog(BuildContext context, HostelOutpass outpass) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'HOSTEL OUTPASS QR',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  boxShadow: const [
                    BoxShadow(blurRadius: 8, color: Colors.black12),
                  ],
                ),
                child: QrImageView(data: outpass.qrPayload ?? '', size: 156),
              ),
              const SizedBox(height: 16),
              Text(
                'Outpass ID: ${outpass.id}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${outpass.studentName} (${outpass.studentCode})',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Valid for Exit & Return',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Security scans this code for exit and return. The student cannot change its state.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
}
