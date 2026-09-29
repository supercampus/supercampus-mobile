import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_system_models.dart';
import '../data/admin_system_repository.dart';
import 'app_versions_screen.dart';
import 'audit_logs_screen.dart';
import 'security_logs_screen.dart';

/// One row in the Admin Desk's System group.
class AdminSystemEntry {
  const AdminSystemEntry({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.build,
  });

  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget Function(
    AdminSystemRepository repository,
    EffectivePermissions permissions,
  )
  build;
}

/// The system pages these grants can open, in display order. Decided by
/// grants only, never by role names.
List<AdminSystemEntry> adminSystemEntries(EffectivePermissions permissions) => [
  if (canViewAuditLogs(permissions))
    AdminSystemEntry(
      id: 'audit_logs',
      icon: Icons.fact_check_rounded,
      color: AppColors.infoInk,
      title: 'Audit logs',
      subtitle: 'Finance audit trail and transaction history',
      build: (repository, _) => AuditLogsScreen(repository: repository),
    ),
  if (canViewSecurityLogs(permissions))
    AdminSystemEntry(
      id: 'security_logs',
      icon: Icons.shield_rounded,
      color: AppColors.hotPinkInk,
      title: 'Security logs',
      subtitle: 'Login sessions, sign-ins and sign-outs',
      build: (repository, permissions) => SecurityLogsScreen(
        repository: repository,
        canRevoke: canRevokeSessions(permissions),
      ),
    ),
  if (canViewAppVersions(permissions))
    AdminSystemEntry(
      id: 'app_versions',
      icon: Icons.system_update_rounded,
      color: AppColors.brandPurple,
      title: 'App versions',
      subtitle: 'Minimum and latest versions per platform',
      build: (repository, permissions) => AppVersionsScreen(
        repository: repository,
        canUpdate: canManageAppVersions(permissions),
      ),
    ),
];
