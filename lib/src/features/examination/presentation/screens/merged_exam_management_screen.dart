import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'exam_configuration_screen.dart';
import 'exam_conduct_screen.dart';
import 'exam_scheduling_screen.dart';

class MergedExamManagementScreen extends StatefulWidget {
  const MergedExamManagementScreen({super.key});

  @override
  State<MergedExamManagementScreen> createState() => _MergedExamManagementScreenState();
}

class _MergedExamManagementScreenState extends State<MergedExamManagementScreen> {
  int _selectedSection = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 600;

        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: 10,
              ),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('1. Configuration'),
                      icon: Icon(Icons.settings_suggest_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('2. Scheduling'),
                      icon: Icon(Icons.calendar_month_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('3. Conduct & Release'),
                      icon: Icon(Icons.security_outlined, size: 16),
                    ),
                  ],
                  selected: {_selectedSection},
                  onSelectionChanged: (set) => setState(() => _selectedSection = set.first),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: IndexedStack(
                index: _selectedSection,
                children: const [
                  ExamConfigurationScreen(),
                  ExamSchedulingScreen(),
                  ExamConductScreen(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
