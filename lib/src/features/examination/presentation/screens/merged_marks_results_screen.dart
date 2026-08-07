import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'grade_gpa_screen.dart';
import 'marks_entry_screen.dart';
import 'moderation_screen.dart';
import 'result_publishing_screen.dart';
import 'revaluation_screen.dart';

class MergedMarksResultsScreen extends StatefulWidget {
  const MergedMarksResultsScreen({super.key});

  @override
  State<MergedMarksResultsScreen> createState() => _MergedMarksResultsScreenState();
}

class _MergedMarksResultsScreenState extends State<MergedMarksResultsScreen> {
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
                      label: Text('Marks Entry'),
                      icon: Icon(Icons.edit_note_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Moderation'),
                      icon: Icon(Icons.tune_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Grade & GPA'),
                      icon: Icon(Icons.functions_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 3,
                      label: Text('Publish Results'),
                      icon: Icon(Icons.publish_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 4,
                      label: Text('Revaluation'),
                      icon: Icon(Icons.find_in_page_outlined, size: 16),
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
                  MarksEntryScreen(),
                  ModerationScreen(),
                  GradeGpaScreen(),
                  ResultPublishingScreen(),
                  RevaluationScreen(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
