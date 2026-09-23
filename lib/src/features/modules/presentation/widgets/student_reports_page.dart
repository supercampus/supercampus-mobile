import 'package:flutter/material.dart';

import '../../../../core/access/module_catalog.dart';
import '../../../library/data/librarian_repository.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../examination/presentation/screens/student_reports_analytics_screen.dart';
import 'campus_wall_screen.dart';
import 'dashboard_nav_bar.dart';

/// Full-screen reports and analytics view equipped with the student DashboardNavBar.
class StudentReportsPage extends StatelessWidget {
  const StudentReportsPage({
    super.key,
    required this.session,
    this.onOpenModule,
    this.onNavSelect,
    this.announcementRepository,
  });

  final UserSession session;
  final ValueChanged<String>? onOpenModule;
  final ValueChanged<String>? onNavSelect;
  final LibrarianRepository? announcementRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF141416) : const Color(0xFFF7F7F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Material(
              color: isDark ? const Color(0xFF2A2A2E) : Colors.white,
              shape: const CircleBorder(),
              elevation: isDark ? 0 : 1,
              shadowColor: Colors.black.withValues(alpha: 0.04),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: textColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Reports & Analysis',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StudentReportsAnalyticsScreen(
        session: session,
      ),
      bottomNavigationBar: DashboardNavBar(
        selectedId: 'analysis',
        onSelect: (id) => _handleNavSelect(context, id),
      ),
    );
  }

  void _handleNavSelect(BuildContext context, String id) {
    if (onNavSelect != null) {
      onNavSelect!(id);
      return;
    }
    switch (id) {
      case 'analysis':
        // Already on reports page
        break;
      case 'wall':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CampusWallScreen(
              session: session,
              onOpenModule: onOpenModule,
              announcementRepository: announcementRepository,
            ),
          ),
        );
        break;
      case 'acads':
        Navigator.of(context).pop();
        onOpenModule?.call(ModuleCatalog.academics);
        break;
      case 'gatepass':
        Navigator.of(context).pop();
        onOpenModule?.call(ModuleCatalog.gatepass);
        break;
    }
  }
}
