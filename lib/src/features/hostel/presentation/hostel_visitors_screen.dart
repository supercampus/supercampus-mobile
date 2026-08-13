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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddVisitorSheet(context),
        backgroundColor: Colors.teal.shade700,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add Visitor'),
      ),
      body: visitors.isEmpty
          ? const Center(child: Text('No visitor passes issued.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visitors.length,
              itemBuilder: (context, index) {
                final v = visitors[index];
                return _buildVisitorCard(context, v);
              },
            ),
    );
  }

  Widget _buildVisitorCard(BuildContext context, VisitorPass v) {
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
                  v.visitorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    v.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Contact: ${v.visitorContact}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            Text(
              'Purpose: ${v.purpose}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Valid Today: ${v.validFromTime} – ${v.validUntilTime}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
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
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                      purpose: purposeCtrl.text.trim().isEmpty ? 'Personal Visit' : purposeCtrl.text.trim(),
                      visitDate: DateTime.now(),
                      validFromTime: '04:00 PM',
                      validUntilTime: '07:00 PM',
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Visitor pass issued successfully!')),
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
