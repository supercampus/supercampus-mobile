import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class StudentEligibilityScreen extends StatefulWidget {
  const StudentEligibilityScreen({super.key});

  @override
  State<StudentEligibilityScreen> createState() => _StudentEligibilityScreenState();
}

class _StudentEligibilityScreenState extends State<StudentEligibilityScreen> {
  String _filter = 'All';

  final List<Map<String, dynamic>> _students = [
    {
      'roll': '2026CS101',
      'name': 'Alex Johnson',
      'programme': 'B.Tech CSE',
      'attendance': 88,
      'feeCleared': true,
      'disciplinaryHold': false,
      'status': 'ELIGIBLE',
    },
    {
      'roll': '2026CS102',
      'name': 'Sophia Martinez',
      'programme': 'B.Tech CSE',
      'attendance': 71,
      'feeCleared': true,
      'disciplinaryHold': false,
      'status': 'BLOCKED',
    },
    {
      'roll': '2026CS103',
      'name': 'Ethan Brown',
      'programme': 'B.Tech CSE',
      'attendance': 92,
      'feeCleared': false,
      'disciplinaryHold': false,
      'status': 'PENDING FEE',
    },
    {
      'roll': '2026CS104',
      'name': 'Olivia Davis',
      'programme': 'B.Tech CSE',
      'attendance': 95,
      'feeCleared': true,
      'disciplinaryHold': true,
      'status': 'BLOCKED',
    },
    {
      'roll': '2026CS105',
      'name': 'Liam Wilson',
      'programme': 'B.Tech CSE',
      'attendance': 82,
      'feeCleared': true,
      'disciplinaryHold': false,
      'status': 'ELIGIBLE',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _students.where((s) {
      if (_filter == 'All') return true;
      if (_filter == 'Eligible') return s['status'] == 'ELIGIBLE';
      if (_filter == 'Blocked') return s['status'] == 'BLOCKED' || s['status'] == 'PENDING FEE';
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRulesHeader(isMobile),
              const SizedBox(height: 14),
              _buildFilterBar(isMobile),
              const SizedBox(height: 14),
              _buildEligibilityContent(filteredStudents, isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRulesHeader(bool isMobile) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Eligibility & Hall Ticket Gatekeeper', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildRuleTag('Attendance', '≥ 75%', Colors.green),
                _buildRuleTag('Fee Clearance', 'Cleared', Colors.blue),
                _buildRuleTag('Disciplinary', 'Clean', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTag(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 12, color: color),
          const SizedBox(width: 4),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'All', label: Text('All')),
              ButtonSegment(value: 'Eligible', label: Text('Eligible')),
              ButtonSegment(value: 'Blocked', label: Text('Blocked/Pending')),
            ],
            selected: {_filter},
            onSelectionChanged: (set) => setState(() => _filter = set.first),
          ),
        ),
      ],
    );
  }

  Widget _buildEligibilityContent(List<Map<String, dynamic>> students, bool isMobile) {
    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: students.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final s = students[index];
          final isEligible = s['status'] == 'ELIGIBLE';

          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isEligible ? Colors.green : Colors.red).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s['status'],
                          style: TextStyle(color: isEligible ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Roll: ${s['roll']} • ${s['programme']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Attendance: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      Text('${s['attendance']}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: s['attendance'] >= 75 ? Colors.green : Colors.red)),
                      const Spacer(),
                      if (isEligible)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () => _showHallTicketDialog(context, s),
                          icon: const Icon(Icons.qr_code_2, size: 14, color: Colors.white),
                          label: const Text('Hall Ticket', style: TextStyle(fontSize: 11, color: Colors.white)),
                        )
                      else
                        TextButton(
                          onPressed: () {},
                          child: const Text('Resolve Block', style: TextStyle(color: Colors.red, fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Roll No')),
            DataColumn(label: Text('Student Name')),
            DataColumn(label: Text('Attendance %')),
            DataColumn(label: Text('Fee Clearance')),
            DataColumn(label: Text('Disciplinary Hold')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Hall Ticket Action')),
          ],
          rows: students.map((s) {
            final isEligible = s['status'] == 'ELIGIBLE';
            return DataRow(
              cells: [
                DataCell(Text(s['roll'], style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(s['name'])),
                DataCell(Text('${s['attendance']}%', style: TextStyle(fontWeight: FontWeight.bold, color: s['attendance'] >= 75 ? Colors.green : Colors.red))),
                DataCell(Icon(s['feeCleared'] ? Icons.check_circle : Icons.cancel, color: s['feeCleared'] ? Colors.green : Colors.red, size: 18)),
                DataCell(Icon(s['disciplinaryHold'] ? Icons.warning : Icons.shield, color: s['disciplinaryHold'] ? Colors.red : Colors.green, size: 18)),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isEligible ? Colors.green : Colors.red).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s['status'],
                    style: TextStyle(color: isEligible ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                )),
                DataCell(
                  isEligible
                      ? OutlinedButton.icon(
                          onPressed: () => _showHallTicketDialog(context, s),
                          icon: const Icon(Icons.qr_code_2, size: 16),
                          label: const Text('View Ticket', style: TextStyle(fontSize: 12)),
                        )
                      : TextButton(
                          onPressed: () {},
                          child: const Text('Resolve Block', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showHallTicketDialog(BuildContext context, Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.badge, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Digital Hall Ticket — ${student['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(student['name'][0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Roll: ${student['roll']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              QrImageView(
                data: 'SUPERCAMPUS-HALLTICKET-${student['roll']}-2026AUTUMN',
                version: QrVersions.auto,
                size: 140.0,
              ),
              const SizedBox(height: 6),
              const Text('Scan at Exam Hall Entrance for Verification', style: TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading Hall Ticket PDF...')),
              );
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }
}
