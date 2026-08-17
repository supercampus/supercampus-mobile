import 'package:flutter/material.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openApplyOutpassSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Request Outpass'),
      ),
      body: outpasses.isEmpty
          ? const Center(child: Text('No outpasses requested yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: outpasses.length,
              itemBuilder: (context, index) {
                final o = outpasses[index];
                return _buildOutpassCard(context, o);
              },
            ),
    );
  }

  Widget _buildOutpassCard(BuildContext context, HostelOutpass outpass) {
    final isApproved = outpass.status == OutpassStatus.approved ||
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    '${outpass.leavingAt.hour}:${outpass.leavingAt.minute.toString().padLeft(2, '0')} PM',
                    Icons.north_east,
                    Colors.orange.shade700,
                  ),
                ),
                Expanded(
                  child: _buildTimeTile(
                    'Expected Return',
                    '${outpass.expectedReturnAt.hour}:${outpass.expectedReturnAt.minute.toString().padLeft(2, '0')} PM',
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
      String title, String timeStr, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            Text(timeStr,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                decoration: const InputDecoration(
                  labelText: 'Reason for Exit',
                ),
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
                            content: Text('Outpass submitted & auto-approved!')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('HOSTEL OUTPASS QR',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simulated QR Code Frame
              Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                ),
                child: CustomPaint(
                  painter: _QrPainter(),
                ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              const SizedBox(height: 16),

              // Simulation Buttons for Gate Exit & Gate Return
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await repository.scanOutpassGate(
                          outpassId: outpass.id,
                          gateName: 'Hostel Main Gate',
                          action: 'EXIT',
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          onRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gate EXIT Recorded successfully! Presence set to OUTSIDE.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Simulate EXIT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await repository.scanOutpassGate(
                          outpassId: outpass.id,
                          gateName: 'Hostel Main Gate',
                          action: 'ENTRY',
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          onRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gate ENTRY Recorded! Outpass Completed.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Simulate RETURN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Corner squares
    canvas.drawRect(Rect.fromLTWH(0, 0, 40, 40), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - 40, 0, 40, 40), paint);
    canvas.drawRect(Rect.fromLTWH(0, size.height - 40, 40, 40), paint);

    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(8, 8, 24, 24), whitePaint);
    canvas.drawRect(Rect.fromLTWH(size.width - 32, 8, 24, 24), whitePaint);
    canvas.drawRect(Rect.fromLTWH(8, size.height - 32, 24, 24), whitePaint);

    canvas.drawRect(Rect.fromLTWH(14, 14, 12, 12), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - 26, 14, 12, 12), paint);
    canvas.drawRect(Rect.fromLTWH(14, size.height - 26, 12, 12), paint);

    // Random pattern grid
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 6; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(50.0 + i * 15, 50.0 + j * 15, 10, 10),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
