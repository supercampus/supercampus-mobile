import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  double _graceMarksLimit = 3;
  double _scalingFactor = 0;
  bool _isLocked = false;

  final List<Map<String, dynamic>> _queue = [
    {
      'subject': 'CS301 Data Structures',
      'evaluator': 'Prof. S. Jenkins',
      'l1Status': 'Passed',
      'l2Status': 'Approved (HoD)',
      'l3Status': 'Verified (Exam Office)',
      'l4Status': 'Pending Controller Lock',
      'outliersCount': 2,
    },
    {
      'subject': 'EC204 Microprocessors',
      'evaluator': 'Dr. K. Patel',
      'l1Status': 'Passed',
      'l2Status': 'Pending HoD Review',
      'l3Status': 'Pending',
      'l4Status': 'Pending',
      'outliersCount': 5,
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
              _buildModerationHeader(isMobile),
              const SizedBox(height: 14),
              _buildVerificationHierarchyCard(isMobile),
              const SizedBox(height: 14),
              if (isMobile) ...[
                _buildRulesPanel(),
                const SizedBox(height: 14),
                _buildLockStatusCard(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRulesPanel()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildLockStatusCard()),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _buildVerificationQueueContent(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModerationHeader(bool isMobile) {
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
            const Icon(Icons.tune, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Moderation & Verification Queue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ensure academic fairness through grace marks, scaling, and L1-L4 sign-offs.',
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

  Widget _buildVerificationHierarchyCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification Hierarchy Levels',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLevelBadge('L1 — Faculty', 'Self Entry', Colors.blue),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.muted,
                ),
                _buildLevelBadge(
                  'L2 — Department',
                  'HoD Review',
                  Colors.indigo,
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.muted,
                ),
                _buildLevelBadge(
                  'L3 — Exam Office',
                  'Compliance',
                  Colors.purple,
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.muted,
                ),
                _buildLevelBadge('L4 — Controller', 'Final Lock', Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(String title, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: color,
            ),
          ),
          Text(
            desc,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesPanel() {
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
            'Moderation Policy Controls',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Max Grace Marks: ${_graceMarksLimit.toInt()} Marks',
            style: const TextStyle(fontSize: 12),
          ),
          Slider(
            value: _graceMarksLimit,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _graceMarksLimit = val),
          ),
          const SizedBox(height: 8),
          Text(
            'Batch Scaling Percentage: ${_scalingFactor.toInt()}%',
            style: const TextStyle(fontSize: 12),
          ),
          Slider(
            value: _scalingFactor,
            min: -5,
            max: 10,
            divisions: 15,
            activeColor: Colors.deepOrange,
            onChanged: (val) => setState(() => _scalingFactor = val),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Moderation rules preview applied.'),
                ),
              );
            },
            icon: const Icon(Icons.calculate, size: 16),
            label: const Text(
              'Apply Moderation Rules',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isLocked ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isLocked ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isLocked ? Icons.lock : Icons.lock_open,
                color: _isLocked ? Colors.red : Colors.green,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isLocked ? 'Marks Locked (Immutable)' : 'Marks Unlocked',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _isLocked ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isLocked
                ? 'Marks frozen by Controller. No modifications allowed.'
                : 'Lock marks to freeze evaluation and trigger GPA Engine.',
            style: TextStyle(
              fontSize: 11,
              color: _isLocked ? Colors.red.shade900 : Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _isLocked ? Colors.red : Colors.green,
              ),
              onPressed: () {
                setState(() => _isLocked = !_isLocked);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isLocked
                          ? 'Marks locked permanently!'
                          : 'Marks unlocked.',
                    ),
                  ),
                );
              },
              icon: Icon(
                _isLocked ? Icons.lock_clock : Icons.lock_open,
                size: 16,
              ),
              label: Text(
                _isLocked ? 'Unlock (Override)' : 'Approve & Lock Marks',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationQueueContent(bool isMobile) {
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
              'Department Verification Queue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          if (isMobile) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _queue.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final q = _queue[index];
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            q['subject'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          Chip(
                            label: Text('${q['outliersCount']} Outliers'),
                            backgroundColor: Colors.purple.withValues(
                              alpha: 0.1,
                            ),
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: Colors.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Evaluator: ${q['evaluator']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Status: ${q['l4Status']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
                  DataColumn(label: Text('Subject Name')),
                  DataColumn(label: Text('Evaluator')),
                  DataColumn(label: Text('L1 Faculty')),
                  DataColumn(label: Text('L2 HoD')),
                  DataColumn(label: Text('L3 Exam Office')),
                  DataColumn(label: Text('L4 Controller Status')),
                  DataColumn(label: Text('Outliers')),
                ],
                rows: _queue.map((q) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          q['subject'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text(q['evaluator'])),
                      DataCell(
                        Text(
                          q['l1Status'],
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                      DataCell(
                        Text(
                          q['l2Status'],
                          style: const TextStyle(color: Colors.indigo),
                        ),
                      ),
                      DataCell(Text(q['l3Status'])),
                      DataCell(
                        Text(
                          q['l4Status'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(
                        Chip(
                          label: Text('${q['outliersCount']} Outliers'),
                          backgroundColor: Colors.purple.withValues(alpha: 0.1),
                          side: BorderSide.none,
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
}
