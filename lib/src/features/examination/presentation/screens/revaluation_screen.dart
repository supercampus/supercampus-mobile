import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class RevaluationScreen extends StatefulWidget {
  const RevaluationScreen({super.key});

  @override
  State<RevaluationScreen> createState() => _RevaluationScreenState();
}

class _RevaluationScreenState extends State<RevaluationScreen> {
  final List<Map<String, dynamic>> _revaluations = [
    {
      'id': 'REV-2026-001',
      'roll': '2026CS103',
      'student': 'Ethan Brown',
      'subject': 'CS301 Data Structures',
      'origMarks': 36,
      'revaluedMarks': 42,
      'feePaid': true,
      'evaluator': 'Dr. M. Vance (Independent)',
      'status': 'Updated (Pass)',
    },
    {
      'id': 'REV-2026-002',
      'roll': '2026CS110',
      'student': 'Daniel Radcliffe',
      'subject': 'CS302 DBMS',
      'origMarks': 48,
      'revaluedMarks': 48,
      'feePaid': true,
      'evaluator': 'Prof. A. Nambiar',
      'status': 'Retained Original',
    },
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
              _buildRulesPolicyBanner(),
              const SizedBox(height: 14),
              if (isMobile) ...[
                _buildNewRequestForm(),
                const SizedBox(height: 14),
                _buildRevaluationContent(isMobile),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildRevaluationContent(isMobile),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildNewRequestForm()),
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
            const Icon(Icons.find_in_page, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Post-Result Revaluation Management',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Student-initiated review of answer scripts assigned to independent evaluators.',
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

  Widget _buildRulesPolicyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.gavel, color: Colors.blue, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rules: Window: 14 days | Higher marks accepted; lower marks NOT penalized | Fee refunded if marks increase',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevaluationContent(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Active Revaluation Requests',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          if (isMobile) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _revaluations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = _revaluations[index];
                final isUpdated = r['revaluedMarks'] > r['origMarks'];

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r['id'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isUpdated ? Colors.green : Colors.grey)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['status'],
                              style: TextStyle(
                                color: isUpdated ? Colors.green : AppColors.ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r['student']} (${r['roll']}) • ${r['subject']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Original: ${r['origMarks']} / 100 → Revalued: ${r['revaluedMarks']} / 100',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Request ID')),
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Subject')),
                  DataColumn(label: Text('Original Marks')),
                  DataColumn(label: Text('Revalued Marks')),
                  DataColumn(label: Text('Evaluator')),
                  DataColumn(label: Text('Final Status')),
                ],
                rows: _revaluations.map((r) {
                  final isUpdated = r['revaluedMarks'] > r['origMarks'];
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          r['id'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${r['student']}\n(${r['roll']})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(Text(r['subject'])),
                      DataCell(Text('${r['origMarks']} / 100')),
                      DataCell(
                        Text(
                          '${r['revaluedMarks']} / 100',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isUpdated ? Colors.green : AppColors.ink,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          r['evaluator'],
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isUpdated ? Colors.green : Colors.grey)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r['status'],
                            style: TextStyle(
                              color: isUpdated ? Colors.green : AppColors.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewRequestForm() {
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
            'Apply for Revaluation',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(labelText: 'Student Roll No'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: 'CS301 Data Structures',
            decoration: const InputDecoration(labelText: 'Subject'),
            isExpanded: true,
            items:
                [
                      'CS301 Data Structures',
                      'CS302 DBMS',
                      'CS303 Operating Systems',
                    ]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.payment, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Fee: \$50 / Subject',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const Spacer(),
              Chip(
                label: const Text('Fee Verified'),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                side: BorderSide.none,
                labelStyle: const TextStyle(fontSize: 10, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Revaluation application submitted!'),
                  ),
                );
              },
              icon: const Icon(Icons.assignment_turned_in, size: 16),
              label: const Text(
                'Submit Application',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
