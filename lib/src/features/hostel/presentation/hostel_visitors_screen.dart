import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

class HostelVisitorsScreen extends StatelessWidget {
  const HostelVisitorsScreen({
    super.key,
    required this.visitors,
    required this.repository,
    required this.onRefresh,
    this.onBack,
  });

  final List<VisitorPass> visitors;
  final HostelRepository repository;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null ? BackButton(onPressed: onBack) : null,
        title: const Text('Hostel Visitor Passes'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        children: [
          Text(
            'Plan a visit',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Submit visitor details once, then follow the approval here.',
            style: TextStyle(color: context.palette.inkSecondary),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openAddVisitorSheet(context),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Request visitor pass'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your visitor passes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${visitors.length}',
                style: TextStyle(color: context.palette.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visitors.isEmpty)
            _emptyState(context, 'No visitor pass requests yet.')
          else
            ...visitors.map((visitor) => _buildVisitorCard(context, visitor)),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.palette.border),
    ),
    child: Row(
      children: [
        Icon(Icons.event_available_outlined, color: context.palette.inkSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message, style: TextStyle(color: context.palette.inkSecondary)),
        ),
      ],
    ),
  );

  Widget _buildVisitorCard(BuildContext context, VisitorPass v) {
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
                  v.visitorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.adaptive(light: Colors.green.shade50, dark: Colors.green.withValues(alpha: 0.18)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    v.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.adaptive(light: Colors.green.shade800, dark: Colors.green.shade200),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Contact: ${v.visitorContact}',
              style: TextStyle(color: context.palette.inkSecondary, fontSize: 12),
            ),
            Text(
              'Purpose: ${v.purpose}',
              style: TextStyle(color: context.palette.inkSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: context.palette.brandInk,
                ),
                const SizedBox(width: 4),
                Text(
                  'Valid Today: ${v.validFromTime} – ${v.validUntilTime}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.palette.brandInk,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAddVisitorSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

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
                'Generate Hostel Visitor Pass',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Visitor Full Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    await repository.inviteVisitor(
                      visitorName: nameCtrl.text.trim(),
                      visitorContact: contactCtrl.text.trim(),
                      purpose: purposeCtrl.text.trim().isEmpty
                          ? 'Personal Visit'
                          : purposeCtrl.text.trim(),
                      visitDate: DateTime.now(),
                      validFromTime: '04:00 PM',
                      validUntilTime: '07:00 PM',
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Visitor pass issued successfully!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Generate Visitor Pass'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
