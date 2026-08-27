import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/data/auth_repository.dart';

class StudentReportsAnalyticsScreen extends StatelessWidget {
  const StudentReportsAnalyticsScreen({
    super.key,
    required this.session,
    this.isParent = false,
  });

  final UserSession session;
  final bool isParent;

  @override
  Widget build(BuildContext context) {
    final studentName = isParent ? 'Alex Johnson (Child)' : session.displayName;
    final rollNo = session.idNumber ?? '2026CS101';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(studentName, rollNo, isMobile),
              const SizedBox(height: 14),
              _buildOverallSummaryGrid(isMobile),
              const SizedBox(height: 16),
              if (isMobile) ...[
                _buildGpaTrendCard(isMobile),
                const SizedBox(height: 14),
                _buildInternalVsExternalCard(isMobile),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildGpaTrendCard(isMobile)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildInternalVsExternalCard(isMobile),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _buildSubjectBreakdownCard(isMobile),
              const SizedBox(height: 18),
              _buildDownloadsCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(String studentName, String rollNo, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isParent
                      ? "$studentName's Academic Report"
                      : 'My Performance Analytics',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Roll: $rollNo • B.Tech Computer Science (Sem 5)',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsCard(BuildContext context) {
    final reports = [
      ('Semester marksheet', Icons.grade_outlined),
      ('Attendance report', Icons.fact_check_outlined),
      ('GPA / CGPA transcript', Icons.insights_outlined),
      ('Subject performance analysis', Icons.analytics_outlined),
      ('Academic progress summary', Icons.timeline_outlined),
    ];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Download academic reports',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Available inside the report section for offline use.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            for (final report in reports)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(report.$2, color: AppColors.primary),
                title: Text(report.$1, style: const TextStyle(fontSize: 13)),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    _downloadButton(
                      context,
                      report.$1,
                      'PDF',
                      Icons.picture_as_pdf_outlined,
                    ),
                    _downloadButton(
                      context,
                      report.$1,
                      'Word',
                      Icons.description_outlined,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _downloadButton(
    BuildContext context,
    String report,
    String format,
    IconData icon,
  ) => OutlinedButton.icon(
    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$report ($format) download started')),
    ),
    icon: Icon(icon, size: 14),
    label: Text(format, style: const TextStyle(fontSize: 10)),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: Size.zero,
    ),
  );

  Widget _buildOverallSummaryGrid(bool isMobile) {
    final stats = [
      {
        'title': 'Cumulative CGPA',
        'val': '9.15 / 10.0',
        'sub': 'Rank #3 in Class',
        'icon': Icons.stars,
        'color': Colors.green,
      },
      {
        'title': 'Current Sem GPA',
        'val': '9.25',
        'sub': 'Semester 5',
        'icon': Icons.grade,
        'color': Colors.blue,
      },
      {
        'title': 'Total Credits',
        'val': '164 Earned',
        'sub': 'Required: 160',
        'icon': Icons.school,
        'color': Colors.purple,
      },
      {
        'title': 'Pass Percentage',
        'val': '100%',
        'sub': '0 Backlogs',
        'icon': Icons.verified,
        'color': Colors.teal,
      },
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: stats.map((s) => _buildStatCard(s)).toList(),
      );
    }

    return Row(
      children: stats
          .map(
            (s) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildStatCard(s),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> s) {
    final color = s['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(s['icon'] as IconData, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s['title'] as String,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s['val'] as String,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            s['sub'] as String,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildGpaTrendCard(bool isMobile) {
    final sems = [
      {'sem': 'Sem 1', 'gpa': 8.80},
      {'sem': 'Sem 2', 'gpa': 9.00},
      {'sem': 'Sem 3', 'gpa': 8.95},
      {'sem': 'Sem 4', 'gpa': 9.10},
      {'sem': 'Sem 5', 'gpa': 9.25},
    ];

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
            'GPA & CGPA Trend Across Semesters',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Column(
            children: sems.map((s) {
              final gpa = s['gpa'] as double;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        s['sem'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: gpa / 10.0,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: Colors.grey.shade100,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      gpa.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInternalVsExternalCard(bool isMobile) {
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
            'Internal vs External Marks (Sem 5)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCompRow('CS301 Data Structures', 28, 30, 65, 70),
          _buildCompRow('CS302 Database Systems', 24, 30, 58, 70),
          _buildCompRow('CS303 Operating Systems', 26, 30, 60, 70),
        ],
      ),
    );
  }

  Widget _buildCompRow(String sub, int ia, int iaMax, int ext, int extMax) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (ia + ext) / (iaMax + extMax),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: Colors.grey.shade100,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'IA: $ia/$iaMax | Ext: $ext/$extMax',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBreakdownCard(bool isMobile) {
    final subjects = [
      {
        'code': 'CS301',
        'name': 'Data Structures & Algorithms',
        'credits': 4,
        'ia': '28/30',
        'ext': '65/70',
        'total': '93/100',
        'grade': 'O',
      },
      {
        'code': 'CS302',
        'name': 'Database Management Systems',
        'credits': 4,
        'ia': '24/30',
        'ext': '58/70',
        'total': '82/100',
        'grade': 'A+',
      },
      {
        'code': 'CS303',
        'name': 'Operating Systems',
        'credits': 3,
        'ia': '26/30',
        'ext': '60/70',
        'total': '86/100',
        'grade': 'A+',
      },
      {
        'code': 'CS304',
        'name': 'Computer Networks',
        'credits': 3,
        'ia': '27/30',
        'ext': '61/70',
        'total': '88/100',
        'grade': 'A+',
      },
    ];

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
            'Subject-wise Performance Breakdown',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (isMobile) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = subjects[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s['code']} ${s['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                            Text(
                              'IA: ${s['ia']} • Ext: ${s['ext']} • Total: ${s['total']}',
                              style: const TextStyle(
                                fontSize: 10.5,
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
                          s['grade'] as String,
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
                  DataColumn(label: Text('Subject Code & Title')),
                  DataColumn(label: Text('Credits')),
                  DataColumn(label: Text('Internal (30)')),
                  DataColumn(label: Text('External (70)')),
                  DataColumn(label: Text('Total Marks')),
                  DataColumn(label: Text('Grade')),
                ],
                rows: subjects.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${s['code']} ${s['name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text(s['credits'].toString())),
                      DataCell(Text(s['ia'] as String)),
                      DataCell(Text(s['ext'] as String)),
                      DataCell(
                        Text(
                          s['total'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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
                            s['grade'] as String,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
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
}
