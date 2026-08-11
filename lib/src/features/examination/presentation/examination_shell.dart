import 'package:flutter/material.dart';
import '../../authentication/data/auth_repository.dart';

import 'screens/admin_examination_dashboard.dart';
import 'screens/exam_scheduling_screen.dart';
import 'screens/grade_gpa_screen.dart';
import 'screens/merged_exam_management_screen.dart';
import 'screens/merged_marks_results_screen.dart';
import 'screens/merged_reports_analytics_screen.dart';
import 'screens/merged_student_management_screen.dart';
import 'screens/parent_examination_dashboard.dart';
import 'screens/student_examination_dashboard.dart';
import 'screens/student_reports_analytics_screen.dart';
import 'screens/student_exam_schedule_screen.dart';

class ExaminationShell extends StatefulWidget {
  const ExaminationShell({
    super.key,
    required this.session,
    this.onExitModule,
    required this.onSignOut,
    this.initialAction,
  });

  final UserSession session;
  final VoidCallback? onExitModule;
  final VoidCallback onSignOut;
  final String? initialAction;

  @override
  State<ExaminationShell> createState() => _ExaminationShellState();
}

class _ExaminationShellState extends State<ExaminationShell> {
  int? _activeFeatureIndex;

  bool get _isStudent => widget.session.role == UserRole.student;
  bool get _isParent => widget.session.role == UserRole.parent;

  @override
  void initState() {
    super.initState();
    _activeFeatureIndex = switch (widget.initialAction) {
      'schedule' => 0,
      'results' => 1,
      'marks' => _isStudent || _isParent ? 1 : 2,
      _ => null,
    };
  }

  String _getFeatureTitle() {
    if (_activeFeatureIndex == null) return 'Examination Dashboard';

    if (_isStudent) {
      switch (_activeFeatureIndex) {
        case 0:
          return 'Exam Schedule & Timetable';
        case 1:
          return 'Semester Results & GPA';
        case 2:
          return 'My Academic Reports & Analytics';
        default:
          return 'Examination System';
      }
    } else if (_isParent) {
      switch (_activeFeatureIndex) {
        case 0:
          return "Child's Exam Schedule";
        case 1:
          return "Child's Results & Grades";
        case 2:
          return "Child's Performance Reports";
        default:
          return 'Examination System';
      }
    } else {
      switch (_activeFeatureIndex) {
        case 0:
          return 'Exam Management (Config, Schedule & Conduct)';
        case 1:
          return 'Student Management (Eligibility & Roster)';
        case 2:
          return 'Marks Entry, Moderation & Results';
        case 3:
          return 'Reports & AI Performance Insights';
        default:
          return 'Examination System';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            leading: _activeFeatureIndex != null
                ? IconButton(
                    tooltip: 'Back to Dashboard',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _activeFeatureIndex = null),
                  )
                : (widget.onExitModule != null
                      ? IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onExitModule,
                        )
                      : null),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFeatureTitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.session.displayName} • ${widget.session.role.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: _isStudent || _isParent
                ? const []
                : [
                    IconButton(
                      tooltip: 'Sign Out',
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: widget.onSignOut,
                    ),
                    const SizedBox(width: 6),
                  ],
          ),
          body: _buildBodyContent(),
        );
      },
    );
  }

  Widget _buildBodyContent() {
    if (_activeFeatureIndex == null) {
      if (_isStudent) {
        return StudentExaminationDashboard(
          session: widget.session,
          onNavigateToFeature: (index) =>
              setState(() => _activeFeatureIndex = index),
        );
      } else if (_isParent) {
        return ParentExaminationDashboard(
          session: widget.session,
          onNavigateToFeature: (index) =>
              setState(() => _activeFeatureIndex = index),
        );
      } else {
        return AdminExaminationDashboard(
          session: widget.session,
          onNavigateToFeature: (index) =>
              setState(() => _activeFeatureIndex = index),
        );
      }
    }

    if (_isStudent) {
      switch (_activeFeatureIndex) {
        case 0:
          return const StudentExamScheduleScreen();
        case 1:
          return const GradeGpaScreen();
        case 2:
          return StudentReportsAnalyticsScreen(
            session: widget.session,
            isParent: false,
          );
        default:
          return StudentExaminationDashboard(
            session: widget.session,
            onNavigateToFeature: (index) =>
                setState(() => _activeFeatureIndex = index),
          );
      }
    } else if (_isParent) {
      switch (_activeFeatureIndex) {
        case 0:
          return const ExamSchedulingScreen();
        case 1:
          return const GradeGpaScreen();
        case 2:
          return StudentReportsAnalyticsScreen(
            session: widget.session,
            isParent: true,
          );
        default:
          return ParentExaminationDashboard(
            session: widget.session,
            onNavigateToFeature: (index) =>
                setState(() => _activeFeatureIndex = index),
          );
      }
    } else {
      switch (_activeFeatureIndex) {
        case 0:
          return const MergedExamManagementScreen();
        case 1:
          return const MergedStudentManagementScreen();
        case 2:
          return const MergedMarksResultsScreen();
        case 3:
          return const MergedReportsAnalyticsScreen();
        default:
          return AdminExaminationDashboard(
            session: widget.session,
            onNavigateToFeature: (index) =>
                setState(() => _activeFeatureIndex = index),
          );
      }
    }
  }
}
