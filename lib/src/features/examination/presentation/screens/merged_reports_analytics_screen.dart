import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'ai_insights_screen.dart';
import 'reports_analytics_screen.dart';

class MergedReportsAnalyticsScreen extends StatefulWidget {
  const MergedReportsAnalyticsScreen({super.key});

  @override
  State<MergedReportsAnalyticsScreen> createState() => _MergedReportsAnalyticsScreenState();
}

class _MergedReportsAnalyticsScreenState extends State<MergedReportsAnalyticsScreen> {
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
                      label: Text('Reports & Exports'),
                      icon: Icon(Icons.assessment_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('AI Performance Insights'),
                      icon: Icon(Icons.psychology_outlined, size: 16),
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
                  ReportsAnalyticsScreen(),
                  AiInsightsScreen(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
