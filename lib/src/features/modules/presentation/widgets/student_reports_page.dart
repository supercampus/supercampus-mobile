import 'package:flutter/material.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/theme/app_theme.dart';
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
    this.onGoHome,
    this.baseUrl,
    this.accessTokenProvider,
    this.permissions,
  });

  final UserSession session;
  final ValueChanged<String>? onOpenModule;
  final ValueChanged<String>? onNavSelect;
  final LibrarianRepository? announcementRepository;

  /// Called after the page pops back to the first route when the user
  /// double-taps Wall or Reports, so a host can also leave an open module.
  final VoidCallback? onGoHome;

  /// The app's resolved backend and token provider. Null in mock builds, where
  /// each report section says it is not available instead of inventing data.
  final String? baseUrl;
  final AccessTokenProvider? accessTokenProvider;

  /// Hides report sections for modules the user may not see.
  final EffectivePermissions? permissions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: p.canvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Material(
                color: p.surface,
                shape: CircleBorder(side: BorderSide(color: p.border)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      semanticLabel: 'Back',
                      color: p.ink,
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
              color: p.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: StudentReportsAnalyticsScreen(
          session: session,
          // The report sits on top of its host; leave it before the host
          // switches to the module, as the nav bar does.
          onOpenModule: onOpenModule == null
              ? null
              : (id) {
                  Navigator.of(context).pop();
                  onOpenModule!(id);
                },
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
          permissions: permissions,
        ),
        bottomNavigationBar: DashboardNavBar(
          selectedId: 'analysis',
          onSelect: (id) => _handleNavSelect(context, id),
          onHome: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            onGoHome?.call();
          },
        ),
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
              onGoHome: onGoHome,
              baseUrl: baseUrl,
              accessTokenProvider: accessTokenProvider,
              permissions: permissions,
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
