import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  String _selectedReport = 'Examination Schedule';

  final List<Map<String, String>> _reportsList = [
    {
      'name': 'Examination Schedule',
      'desc': 'Date-wise exam timetable export',
      'formats': 'PDF, Excel',
    },
    {
      'name': 'Student Eligibility',
      'desc': 'Eligible / Ineligible student roster',
      'formats': 'Excel, PDF',
    },
    {
      'name': 'Marks Summary',
      'desc': 'Subject-wise marks distribution grid',
      'formats': 'Excel, CSV',
    },
    {
      'name': 'Moderation Summary',
      'desc': 'Grace marks & scaling audit log',
      'formats': 'Excel, PDF',
    },
    {
      'name': 'Pass/Fail Analysis',
      'desc': 'Programme & subject-wise pass rates',
      'formats': 'PDF, Chart',
    },
    {
      'name': 'Grade Distribution',
      'desc': 'Histogram breakdown of letter grades',
      'formats': 'PDF, Chart',
    },
    {
      'name': 'GPA/CGPA Analysis',
      'desc': 'Class ranking & academic standing report',
      'formats': 'Excel, PDF',
    },
    {
      'name': 'Degree Audit Report',
      'desc': 'Pending degree requirements by student',
      'formats': 'Excel, PDF',
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
              _buildFilterBar(),
              const SizedBox(height: 14),
              if (isMobile) ...[
                _buildReportTemplateSelector(isMobile),
                const SizedBox(height: 14),
                _buildReportPreviewCard(isMobile),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildReportTemplateSelector(isMobile),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: _buildReportPreviewCard(isMobile)),
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
      color: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.palette.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            Icon(
              Icons.assessment_outlined,
              color: context.palette.brandInk,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reporting & Export Engine',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Extract institutional compliance reports, marks grids, and degree analytics.',
                    style: TextStyle(fontSize: 11, color: context.palette.inkSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_outlined,
            color: context.palette.inkSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDropdownChip('Year: 2026-2027'),
                  const SizedBox(width: 6),
                  _buildDropdownChip('Programme: B.Tech CSE'),
                  const SizedBox(width: 6),
                  _buildDropdownChip('Semester: Sem 5'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: context.palette.canvas,
      side: BorderSide(color: context.palette.border),
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildReportTemplateSelector(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Report Templates',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reportsList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = _reportsList[index];
              final isSelected = r['name'] == _selectedReport;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                selected: isSelected,
                selectedTileColor: context.adaptive(
                  light: AppColors.primary.withValues(alpha: 0.1),
                  dark: context.palette.brandSoft,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  r['name']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12.5,
                    color: isSelected ? context.palette.brandInk : context.palette.ink,
                  ),
                ),
                subtitle: Text(
                  r['desc']!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.palette.inkSecondary,
                  ),
                ),
                onTap: () => setState(() => _selectedReport = r['name']!),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportPreviewCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedReport,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exporting Report to Excel...'),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.table_chart,
                  size: 14,
                  color: Colors.green,
                ),
                label: const Text('Excel', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.palette.brand,
                  foregroundColor: context.palette.onBrand,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting Report to PDF...')),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 14),
                label: const Text('PDF', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: isMobile ? 220 : 300,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.table_rows, size: 40, color: context.palette.inkSecondary),
                const SizedBox(height: 10),
                Text(
                  'Data Ready for $_selectedReport',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '65 Records Loaded • Autumn Semester 2026',
                  style: TextStyle(fontSize: 11, color: context.palette.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
