import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ResultPublishingScreen extends StatefulWidget {
  const ResultPublishingScreen({super.key});

  @override
  State<ResultPublishingScreen> createState() => _ResultPublishingScreenState();
}

class _ResultPublishingScreenState extends State<ResultPublishingScreen> {
  bool _isPublished = false;
  String _selectedScope = 'Programme-wise Staggered Release';

  final List<Map<String, dynamic>> _publishChecklist = [
    {'check': 'Final Marks Locked for all subjects', 'done': true},
    {'check': 'Grades & GPA/CGPA calculated with zero errors', 'done': true},
    {'check': 'Degree & Academic Probation checks validated', 'done': true},
    {'check': 'Department Level Review Sign-off complete', 'done': true},
    {'check': 'Controller Level Approval Granted', 'done': true},
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(isMobile),
              const SizedBox(height: 14),
              _buildPublishingStepper(isMobile),
              const SizedBox(height: 16),
              if (isMobile) ...[
                _buildPublishControlPanel(),
                const SizedBox(height: 14),
                _buildPrePublishChecklistCard(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildPrePublishChecklistCard()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildPublishControlPanel()),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(bool isMobile) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            const Icon(Icons.publish, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Result Approval & Publishing Panel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Staggered publication, embargo release controls, and recipient notifications.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishingStepper(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: const [
            _StepItem(step: '1', title: 'Marks Lock', done: true),
            _StepDivider(),
            _StepItem(step: '2', title: 'Calculate GPA', done: true),
            _StepDivider(),
            _StepItem(step: '3', title: 'Result Review', done: true),
            _StepDivider(),
            _StepItem(step: '4', title: 'Controller Sign-off', done: true),
            _StepDivider(),
            _StepItem(step: '5', title: 'Publish Live', done: false),
          ],
        ),
      ),
    );
  }

  Widget _buildPrePublishChecklistCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pre-Publish Verification Checklist',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _publishChecklist.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = _publishChecklist[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 18,
                ),
                title: Text(
                  c['check'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPublishControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Publishing Release Settings',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedScope,
            decoration: const InputDecoration(labelText: 'Release Scope'),
            isExpanded: true,
            items:
                [
                      'Programme-wise Staggered Release',
                      'Batch-wide Immediate Release',
                      'Embargo Hold (Scheduled Release)',
                    ]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (val) => setState(() => _selectedScope = val!),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rollback Protection: Published results cannot be altered directly. Corrections require Revaluation.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _isPublished
                    ? Colors.green
                    : AppColors.primary,
              ),
              onPressed: () {
                setState(() => _isPublished = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Results Published! Push notifications sent.',
                    ),
                  ),
                );
              },
              icon: Icon(_isPublished ? Icons.verified : Icons.send, size: 16),
              label: Text(
                _isPublished
                    ? 'Results Published (Live)'
                    : 'Publish Results Now',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.step,
    required this.title,
    required this.done,
  });
  final String step;
  final String title;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: done ? Colors.green : Colors.grey.shade300,
          child: done
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : Text(
                  step,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: done ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 2,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
