import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class GradeGpaScreen extends StatefulWidget {
  const GradeGpaScreen({super.key});

  @override
  State<GradeGpaScreen> createState() => _GradeGpaScreenState();
}

class _GradeGpaScreenState extends State<GradeGpaScreen> {
  final List<Map<String, dynamic>> _gradeScheme = [
    {
      'range': '90 - 100%',
      'grade': 'O (Outstanding)',
      'gp': 10,
      'result': 'Pass',
    },
    {'range': '80 - 89%', 'grade': 'A+ (Excellent)', 'gp': 9, 'result': 'Pass'},
    {'range': '70 - 79%', 'grade': 'A (Very Good)', 'gp': 8, 'result': 'Pass'},
    {'range': '60 - 69%', 'grade': 'B+ (Good)', 'gp': 7, 'result': 'Pass'},
    {
      'range': '55 - 59%',
      'grade': 'B (Above Average)',
      'gp': 6,
      'result': 'Pass',
    },
    {'range': '50 - 54%', 'grade': 'C (Average)', 'gp': 5, 'result': 'Pass'},
    {'range': '45 - 49%', 'grade': 'P (Pass)', 'gp': 4, 'result': 'Pass'},
    {'range': '< 45%', 'grade': 'F (Fail)', 'gp': 0, 'result': 'Fail'},
  ];

  final List<Map<String, dynamic>> _sampleStudentResults = [
    {
      'code': 'CS301',
      'name': 'Data Structures',
      'credits': 4,
      'marks': 93,
      'grade': 'O',
      'gp': 10,
      'earned': 40,
    },
    {
      'code': 'CS302',
      'name': 'DBMS',
      'credits': 4,
      'marks': 82,
      'grade': 'A+',
      'gp': 9,
      'earned': 36,
    },
    {
      'code': 'CS303',
      'name': 'Operating Systems',
      'credits': 3,
      'marks': 75,
      'grade': 'A',
      'gp': 8,
      'earned': 24,
    },
    {
      'code': 'CS304',
      'name': 'Computer Networks',
      'credits': 3,
      'marks': 88,
      'grade': 'A+',
      'gp': 9,
      'earned': 27,
    },
    {
      'code': 'CS305',
      'name': 'Software Engineering',
      'credits': 2,
      'marks': 91,
      'grade': 'O',
      'gp': 10,
      'earned': 20,
    },
  ];

  @override
  Widget build(BuildContext context) {
    int totalCredits = 0;
    int totalPointsEarned = 0;
    for (var r in _sampleStudentResults) {
      totalCredits += (r['credits'] as int);
      totalPointsEarned += (r['earned'] as int);
    }
    double gpa = totalCredits > 0 ? (totalPointsEarned / totalCredits) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBanner(isMobile),
              const SizedBox(height: 14),
              _buildGpaCalculatorCard(
                gpa,
                totalCredits,
                totalPointsEarned,
                isMobile,
              ),
              const SizedBox(height: 16),
              if (isMobile) ...[
                _buildStudentBreakdownContent(isMobile),
                const SizedBox(height: 16),
                _buildGradeSchemeTable(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildStudentBreakdownContent(isMobile),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildGradeSchemeTable()),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBanner(bool isMobile) {
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
            const Icon(Icons.functions, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grade & GPA Calculation Engine',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Automated letter grade mapping and credit weightage product.',
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

  Widget _buildGpaCalculatorCard(
    double gpa,
    int credits,
    int points,
    bool isMobile,
  ) {
    String standing = 'First Class with Distinction';
    Color standingColor = Colors.green;
    if (gpa < 9.0 && gpa >= 7.5) {
      standing = 'First Class';
      standingColor = Colors.blue;
    } else if (gpa < 7.5 && gpa >= 6.0) {
      standing = 'Second Class';
      standingColor = Colors.orange;
    } else if (gpa < 6.0) {
      standing = 'Academic Probation';
      standingColor = Colors.red;
    }

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: standingColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: standingColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: standingColor,
                  child: Text(
                    gpa.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        standing,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: standingColor,
                        ),
                      ),
                      Text(
                        'Earned Credits: $credits • Points: $points',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: standingColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: standingColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: standingColor,
            child: Text(
              gpa.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Calculated Semester GPA: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      gpa.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: standingColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(standing),
                      backgroundColor: standingColor.withValues(alpha: 0.15),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: standingColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Earned Credits: $credits | Points: $points | Equiv: ${(gpa * 10).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentBreakdownContent(bool isMobile) {
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
              'Student Grade Breakdown (Alex Johnson)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          if (isMobile) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sampleStudentResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = _sampleStudentResults[index];
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['code']} ${r['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Credits: ${r['credits']} • Marks: ${r['marks']}%',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${r['grade']} (${r['gp']} GP)',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
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
                  DataColumn(label: Text('Subject')),
                  DataColumn(label: Text('Credits')),
                  DataColumn(label: Text('Final % Marks')),
                  DataColumn(label: Text('Letter Grade')),
                  DataColumn(label: Text('Grade Point')),
                  DataColumn(label: Text('Earned Points')),
                ],
                rows: _sampleStudentResults.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${r['code']} ${r['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(r['credits'].toString())),
                      DataCell(Text('${r['marks']}%')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r['grade'],
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(r['gp'].toString())),
                      DataCell(
                        Text(
                          r['earned'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildGradeSchemeTable() {
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
          const Text(
            'Institutional Grade Scheme',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _gradeScheme.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final g = _gradeScheme[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  g['grade'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  'Range: ${g['range']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                trailing: Text(
                  'GP: ${g['gp']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
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
