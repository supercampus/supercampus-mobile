import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

class HostelComplaintsScreen extends StatelessWidget {
  const HostelComplaintsScreen({
    super.key,
    required this.complaints,
    required this.repository,
    required this.onRefresh,
    this.onBack,
  });

  final List<HostelComplaint> complaints;
  final HostelRepository repository;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null ? BackButton(onPressed: onBack) : null,
        title: const Text('Maintenance & Complaints'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewComplaintSheet(context),
        backgroundColor: Colors.red.shade700,
        icon: const Icon(Icons.add),
        label: const Text('Report Issue'),
      ),
      body: complaints.isEmpty
          ? const Center(child: Text('No complaints logged.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: complaints.length,
              itemBuilder: (context, index) {
                final c = complaints[index];
                return _buildComplaintCard(context, c);
              },
            ),
    );
  }

  Widget _buildComplaintCard(BuildContext context, HostelComplaint complaint) {
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
                  '${complaint.id} · Room ${complaint.roomNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    complaint.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Category: ${complaint.category}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              complaint.description,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (complaint.assignedTo != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${complaint.assignedTo}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openNewComplaintSheet(BuildContext context) {
    String selectedCategory = 'Electrical';
    final descCtrl = TextEditingController();

    final categories = [
      'Electrical',
      'Plumbing',
      'Furniture',
      'Cleaning',
      'Internet',
      'Room',
      'Bathroom',
      'Water',
      'Common Area',
      'Other',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    'Report Maintenance Issue',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Describe the problem...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (descCtrl.text.trim().isEmpty) return;
                        await repository.submitComplaint(
                          category: selectedCategory,
                          description: descCtrl.text.trim(),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          onRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Complaint submitted to Maintenance team.')),
                          );
                        }
                      },
                      child: const Text('Submit Complaint Ticket'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
