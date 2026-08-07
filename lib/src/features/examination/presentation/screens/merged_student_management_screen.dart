import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'degree_audit_screen.dart';
import 'student_eligibility_screen.dart';

class MergedStudentManagementScreen extends StatefulWidget {
  const MergedStudentManagementScreen({super.key});

  @override
  State<MergedStudentManagementScreen> createState() => _MergedStudentManagementScreenState();
}

class _MergedStudentManagementScreenState extends State<MergedStudentManagementScreen> {
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
                      label: Text('Eligibility & Hall Tickets'),
                      icon: Icon(Icons.verified_user_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Degree Audit'),
                      icon: Icon(Icons.school_outlined, size: 16),
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
                  StudentEligibilityScreen(),
                  DegreeAuditScreen(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
