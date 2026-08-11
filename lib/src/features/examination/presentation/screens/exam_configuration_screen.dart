import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ExamConfigurationScreen extends StatefulWidget {
  const ExamConfigurationScreen({super.key});

  @override
  State<ExamConfigurationScreen> createState() =>
      _ExamConfigurationScreenState();
}

class _ExamConfigurationScreenState extends State<ExamConfigurationScreen> {
  String _selectedYear = '2026-2027';
  String _selectedProgramme = 'B.Tech Computer Science & Engineering';
  String _selectedPattern = '70-30 Semester Pattern (70 External / 30 IA)';

  double _iaWeightage = 30;
  double _externalWeightage = 70;
  double _minPassPercent = 40;

  final List<Map<String, String>> _checklist = [
    {
      'id': '1',
      'item': 'Academic Calendar Defined',
      'role': 'Academic Admin',
      'status': 'Configured',
    },
    {
      'id': '2',
      'item': 'Curriculum Version Active',
      'role': 'Programme Coordinator',
      'status': 'Configured',
    },
    {
      'id': '3',
      'item': 'Subjects with Credits Mapped',
      'role': 'Academic Admin',
      'status': 'Configured',
    },
    {
      'id': '4',
      'item': 'Examination Pattern Defined',
      'role': 'Examination Controller',
      'status': 'In Progress',
    },
    {
      'id': '5',
      'item': 'Grade Scheme Configured',
      'role': 'Examination Controller',
      'status': 'Configured',
    },
    {
      'id': '6',
      'item': 'Moderation Rules Set',
      'role': 'HoD / Dean',
      'status': 'Pending',
    },
    {
      'id': '7',
      'item': 'Invigilator Pool Defined',
      'role': 'Examination Admin',
      'status': 'Configured',
    },
    {
      'id': '8',
      'item': 'Hall / Room Master Updated',
      'role': 'Facilities Admin',
      'status': 'Configured',
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
              _buildHeader(isMobile),
              const SizedBox(height: 16),
              if (isMobile) ...[
                _buildConfigForm(isMobile),
                const SizedBox(height: 16),
                _buildChecklistCard(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildConfigForm(isMobile)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildChecklistCard()),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
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
            const Icon(
              Icons.settings_suggest,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Examination Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Define academic hierarchy, assessment weightages, credit mapping, and passing rules.',
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

  Widget _buildConfigForm(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Academic & Exam Hierarchy',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(labelText: 'Academic Year'),
            items: [
              '2026-2027',
              '2025-2026',
              '2024-2025',
            ].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
            onChanged: (val) => setState(() => _selectedYear = val!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedProgramme,
            decoration: const InputDecoration(labelText: 'Programme'),
            isExpanded: true,
            items:
                [
                      'B.Tech Computer Science & Engineering',
                      'B.Tech Electronics & Communication',
                      'B.Tech Mechanical Engineering',
                      'MBA Business Analytics',
                    ]
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
            onChanged: (val) => setState(() => _selectedProgramme = val!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedPattern,
            decoration: const InputDecoration(labelText: 'Examination Pattern'),
            isExpanded: true,
            items:
                [
                      '70-30 Semester Pattern (70 External / 30 IA)',
                      '60-40 Continuous Evaluation Pattern',
                      '50-50 Theory & Practical Split',
                    ]
                    .map(
                      (pt) => DropdownMenuItem(
                        value: pt,
                        child: Text(pt, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
            onChanged: (val) => setState(() => _selectedPattern = val!),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            'Assessment Weightage Split (%)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Internal Assessment (IA): ${_iaWeightage.toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Slider(
                  value: _iaWeightage,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _iaWeightage = val;
                      _externalWeightage = 100 - val;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'External End-Sem Exam: ${_externalWeightage.toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Slider(
                  value: _externalWeightage,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() {
                      _externalWeightage = val;
                      _iaWeightage = 100 - val;
                    });
                  },
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Internal Assessment (IA): ${_iaWeightage.toInt()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Slider(
                        value: _iaWeightage,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _iaWeightage = val;
                            _externalWeightage = 100 - val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'External End-Sem Exam: ${_externalWeightage.toInt()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Slider(
                        value: _externalWeightage,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: Colors.teal,
                        onChanged: (val) {
                          setState(() {
                            _externalWeightage = val;
                            _iaWeightage = 100 - val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minimum Passing Criteria per Component: ${_minPassPercent.toInt()}%',
                style: const TextStyle(fontSize: 12),
              ),
              Slider(
                value: _minPassPercent,
                min: 30,
                max: 60,
                divisions: 6,
                activeColor: Colors.deepOrange,
                onChanged: (val) => setState(() => _minPassPercent = val),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                // TODO: Save configuration payload to POST /api/v1/examination/config
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Examination configuration saved successfully!',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text(
                'Save & Activate Pattern',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
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
          const Row(
            children: [
              Icon(Icons.checklist, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Configuration Readiness',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _checklist.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _checklist[index];
              final isDone = item['status'] == 'Configured';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isDone ? Icons.check_circle : Icons.pending,
                  color: isDone ? Colors.green : Colors.orange,
                  size: 18,
                ),
                title: Text(
                  item['item']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                subtitle: Text(
                  item['role']!,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isDone ? Colors.green : Colors.orange).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item['status']!,
                    style: TextStyle(
                      color: isDone ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
