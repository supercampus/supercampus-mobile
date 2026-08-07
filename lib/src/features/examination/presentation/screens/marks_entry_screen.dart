import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  String _selectedSubject = 'CS301 Data Structures & Algorithms';
  
  final List<Map<String, dynamic>> _marksData = [
    {
      'roll': '2026CS101',
      'name': 'Alex Johnson',
      'iaMarks': 28,
      'extMarks': 65,
      'total': 93,
      'status': 'Valid',
      'outlier': false,
    },
    {
      'roll': '2026CS102',
      'name': 'Sophia Martinez',
      'iaMarks': 22,
      'extMarks': 58,
      'total': 80,
      'status': 'Valid',
      'outlier': false,
    },
    {
      'roll': '2026CS103',
      'name': 'Ethan Brown',
      'iaMarks': 14,
      'extMarks': 22,
      'total': 36,
      'status': 'Fail Warning',
      'outlier': false,
    },
    {
      'roll': '2026CS104',
      'name': 'Olivia Davis',
      'iaMarks': 30,
      'extMarks': 70,
      'total': 100,
      'status': 'Outlier (Top 1%)',
      'outlier': true,
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
              _buildSelectorHeader(isMobile),
              const SizedBox(height: 14),
              _buildValidationSummary(isMobile),
              const SizedBox(height: 14),
              _buildSpreadsheetContent(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectorHeader(bool isMobile) {
    if (isMobile) {
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
                Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text('Faculty Marks Entry Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: const InputDecoration(labelText: 'Assigned Subject'),
              isExpanded: true,
              items: [
                'CS301 Data Structures & Algorithms',
                'CS302 Database Management Systems',
                'CS303 Operating Systems',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) => setState(() => _selectedSubject = val!),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Secure Faculty Marks Entry Portal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Role: Subject Evaluator • Real-time validation checks active', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: const InputDecoration(labelText: 'Assigned Subject'),
              items: [
                'CS301 Data Structures & Algorithms',
                'CS302 Database Management Systems',
                'CS303 Operating Systems',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) => setState(() => _selectedSubject = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationSummary(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Max IA = 30 | Max External = 70 | Outliers flagged at ±3σ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetContent(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Marks Entry Sheet (65 Students)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    if (!isMobile)
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Marks draft saved successfully!')),
                              );
                            },
                            icon: const Icon(Icons.drafts_outlined, size: 16),
                            label: const Text('Save Draft'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Marks submitted for Verification!')),
                              );
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('Submit for Verification'),
                          ),
                        ],
                      ),
                  ],
                ),
                if (isMobile) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marks draft saved successfully!')),
                            );
                          },
                          icon: const Icon(Icons.drafts_outlined, size: 16),
                          label: const Text('Save Draft', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marks submitted for Verification!')),
                            );
                          },
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Submit', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isMobile) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _marksData.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _marksData[index];
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(row['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: row['outlier']
                                  ? Colors.purple.withValues(alpha: 0.12)
                                  : (row['total'] < 40 ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              row['status'],
                              style: TextStyle(
                                color: row['outlier']
                                    ? Colors.purple
                                    : (row['total'] < 40 ? Colors.red : Colors.green),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text('Roll: ${row['roll']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: row['iaMarks'].toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'IA (30)'),
                              onChanged: (val) {
                                final parsed = int.tryParse(val) ?? 0;
                                setState(() {
                                  row['iaMarks'] = parsed;
                                  row['total'] = row['iaMarks'] + row['extMarks'];
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: row['extMarks'].toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'External (70)'),
                              onChanged: (val) {
                                final parsed = int.tryParse(val) ?? 0;
                                setState(() {
                                  row['extMarks'] = parsed;
                                  row['total'] = row['iaMarks'] + row['extMarks'];
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: [
                              const Text('Total', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                              Text('${row['total']}/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
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
                  DataColumn(label: Text('Roll No')),
                  DataColumn(label: Text('Student Name')),
                  DataColumn(label: Text('Internal Marks (Max 30)')),
                  DataColumn(label: Text('External Marks (Max 70)')),
                  DataColumn(label: Text('Total (100)')),
                  DataColumn(label: Text('Validation Status')),
                ],
                rows: _marksData.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row['roll'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['name'])),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: row['iaMarks'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                            onChanged: (val) {
                              final parsed = int.tryParse(val) ?? 0;
                              setState(() {
                                row['iaMarks'] = parsed;
                                row['total'] = row['iaMarks'] + row['extMarks'];
                              });
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: row['extMarks'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                            onChanged: (val) {
                              final parsed = int.tryParse(val) ?? 0;
                              setState(() {
                                row['extMarks'] = parsed;
                                row['total'] = row['iaMarks'] + row['extMarks'];
                              });
                            },
                          ),
                        ),
                      ),
                      DataCell(Text('${row['total']} / 100', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: row['outlier']
                              ? Colors.purple.withValues(alpha: 0.12)
                              : (row['total'] < 40 ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          row['status'],
                          style: TextStyle(
                            color: row['outlier']
                                ? Colors.purple
                                : (row['total'] < 40 ? Colors.red : Colors.green),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
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
}
