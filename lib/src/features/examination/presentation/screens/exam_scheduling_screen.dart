import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ExamSchedulingScreen extends StatefulWidget {
  const ExamSchedulingScreen({super.key});

  @override
  State<ExamSchedulingScreen> createState() => _ExamSchedulingScreenState();
}

class _ExamSchedulingScreenState extends State<ExamSchedulingScreen> {
  final List<Map<String, String>> _schedules = [
    {
      'code': 'CS301',
      'subject': 'Data Structures & Algorithms',
      'date': '15 Oct 2026',
      'slot': '09:30 AM - 12:30 PM',
      'hall': 'Auditorium Hall A (Cap: 150)',
      'invigilator': 'Dr. R. Sharma & Prof. M. Verma',
      'status': 'No Conflict',
    },
    {
      'code': 'CS302',
      'subject': 'Database Management Systems',
      'date': '17 Oct 2026',
      'slot': '09:30 AM - 12:30 PM',
      'hall': 'Exam Block Room 204 (Cap: 60)',
      'invigilator': 'Prof. S. Jenkins',
      'status': 'Capacity Conflict',
    },
    {
      'code': 'CS303',
      'subject': 'Operating Systems',
      'date': '19 Oct 2026',
      'slot': '02:00 PM - 05:00 PM',
      'hall': 'Exam Block Room 102 (Cap: 80)',
      'invigilator': 'Dr. A. Gupta',
      'status': 'No Conflict',
    },
    {
      'code': 'EC301',
      'subject': 'Digital Signal Processing',
      'date': '21 Oct 2026',
      'slot': '09:30 AM - 12:30 PM',
      'hall': 'Auditorium Hall B (Cap: 120)',
      'invigilator': 'Prof. K. Patel',
      'status': 'No Conflict',
    },
  ];

  final List<Map<String, String>> _conflicts = [
    {'type': 'Student/Subject Conflict', 'desc': 'Student assigned to 2 exams at same slot', 'auto': 'No', 'action': 'Reschedule one exam'},
    {'type': 'Hall Conflict', 'desc': 'Same hall assigned to 2 exams simultaneously', 'auto': 'Yes', 'action': 'Reallocate hall'},
    {'type': 'Invigilator Conflict', 'desc': 'Invigilator assigned to multiple halls', 'auto': 'Yes', 'action': 'Reassign invigilator'},
    {'type': 'Capacity Conflict', 'desc': 'Hall capacity < registered students', 'auto': 'Yes', 'action': 'Split batch / Change hall'},
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
              _buildTopBar(isMobile),
              const SizedBox(height: 14),
              _buildConstraintsBanner(isMobile),
              const SizedBox(height: 16),
              _buildTimetableSection(isMobile),
              const SizedBox(height: 20),
              _buildConflictResolutionSection(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exam Scheduling & Allocation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink)),
          const Text('Assign date, time slot, venue, and invigilation.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conflict validation check finished. 1 capacity conflict detected.')),
                    );
                  },
                  icon: const Icon(Icons.rule, size: 16),
                  label: const Text('Conflict Check', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Schedule published successfully!')),
                    );
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Publish Schedule', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Examination Scheduling & Allocation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink)),
              Text('Assign date, time slot, venue, and invigilation with automated zero-conflict validation.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conflict validation check finished. 1 capacity conflict detected.')),
            );
          },
          icon: const Icon(Icons.rule),
          label: const Text('Run Conflict Check'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Schedule published successfully to Student & Faculty Portals!')),
            );
          },
          icon: const Icon(Icons.send),
          label: const Text('Publish Schedule'),
        ),
      ],
    );
  }

  Widget _buildConstraintsBanner(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Active Constraints: Min gap between exams: 24 hrs | Max exams/day: 1 | Hall capacity buffer: 10% | Invigilator ratio: 1:30',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableSection(bool isMobile) {
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
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Scheduled Examinations Timetable', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
              ],
            ),
          ),
          if (isMobile) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _schedules.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _schedules[index];
                final isConflict = row['status'] != 'No Conflict';
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(row['code']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isConflict ? Colors.red : Colors.green).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              row['status']!,
                              style: TextStyle(color: isConflict ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(row['subject']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.event, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text('${row['date']} • ${row['slot']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.room_outlined, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Expanded(child: Text(row['hall']!, style: const TextStyle(fontSize: 11, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
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
                  DataColumn(label: Text('Subject Code & Name')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Time Slot')),
                  DataColumn(label: Text('Venue / Hall')),
                  DataColumn(label: Text('Invigilator(s)')),
                  DataColumn(label: Text('Conflict Status')),
                ],
                rows: _schedules.map((row) {
                  final isConflict = row['status'] != 'No Conflict';
                  return DataRow(
                    cells: [
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(row['code']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(row['subject']!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      )),
                      DataCell(Text(row['date']!)),
                      DataCell(Text(row['slot']!)),
                      DataCell(Text(row['hall']!)),
                      DataCell(Text(row['invigilator']!)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isConflict ? Colors.red : Colors.green).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          row['status']!,
                          style: TextStyle(color: isConflict ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      )),
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

  Widget _buildConflictResolutionSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.report_problem_outlined, color: Colors.deepOrange, size: 20),
              SizedBox(width: 8),
              Text('Conflict Rules & Resolution Matrix', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _conflicts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = _conflicts[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(c['type']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                subtitle: Text('${c['desc']}\nResolution: ${c['action']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c['auto'] == 'Yes' ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Auto: ${c['auto']}',
                    style: TextStyle(
                      color: c['auto'] == 'Yes' ? Colors.blue : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
