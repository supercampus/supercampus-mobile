import 'package:flutter/material.dart';

import '../../../../core/access/academic_presentation.dart';
import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/access/portal_module_presentation.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../insights/data/insight.dart';
import '../../../settings/data/support_repository.dart';
import '../../../settings/presentation/help_center_page.dart';
import '../../../settings/presentation/profile_details_page.dart';

/// Shared chrome: rounded top, grab handle, title.
Future<T?> showHomeSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        key: const ValueKey('home-sheet-surface'),
        color: context.palette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * (expand ? 0.85 : 0.7),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Searches the catalog the user can actually see — modules by name and
/// tagline, and the features they hold a grant on. Matching a feature opens
/// its module, because that is the only place the feature exists.
class CampusSearchSheet extends StatefulWidget {
  const CampusSearchSheet({
    super.key,
    this.session,
    required this.permissions,
    required this.onOpenModule,
  });

  final UserSession? session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;

  @override
  State<CampusSearchSheet> createState() => _CampusSearchSheetState();
}

class _CampusSearchSheetState extends State<CampusSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = _search(_query);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: TextField(
            key: const ValueKey('search-field'),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'search anything',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Flexible(
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Text(
                    _query.trim().isEmpty
                        ? 'Search across every campus service you have access to.'
                        : 'Nothing matches “$_query”.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final result = results[i];
                    final ready = result.module.status != ModuleStatus.planned;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: result.module.color.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          result.module.icon,
                          color: result.module.color,
                          size: 20,
                        ),
                      ),
                      title: Text(result.title),
                      subtitle: Text(
                        ready ? result.subtitle : 'Coming soon',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      enabled: ready,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onOpenModule(result.module.id);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<_SearchResult> _search(String raw) {
    final query = raw.trim().toLowerCase();
    final modules = widget.session == null
        ? presentedModules(widget.permissions)
        : portalModules(widget.session!, widget.permissions);
    if (query.isEmpty) {
      return [
        for (final m in modules)
          _SearchResult(module: m, title: m.title, subtitle: m.tagline),
      ];
    }

    final results = <_SearchResult>[];
    for (final module in modules) {
      final matchesModule =
          module.title.toLowerCase().contains(query) ||
          module.tagline.toLowerCase().contains(query) ||
          module.keywords.any((word) => word.contains(query));

      if (matchesModule) {
        results.add(
          _SearchResult(
            module: module,
            title: module.title,
            subtitle: module.tagline,
          ),
        );
      }

      for (final feature in widget.permissions.grantedFeatures(module)) {
        if (!feature.label.toLowerCase().contains(query)) continue;
        results.add(
          _SearchResult(
            module: module,
            title: feature.label,
            subtitle: 'in ${moduleLabelFor(module, widget.permissions)}',
          ),
        );
      }
    }
    return results;
  }
}

class _SearchResult {
  const _SearchResult({
    required this.module,
    required this.title,
    required this.subtitle,
  });

  final ModuleDescriptor module;
  final String title;
  final String subtitle;
}

/// The full module catalog opened from the primary Modules tab.
class ModuleListSheet extends StatelessWidget {
  const ModuleListSheet({
    super.key,
    this.session,
    required this.permissions,
    required this.onOpenModule,
    this.moduleOrder = const [],
  });

  final UserSession? session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final List<String> moduleOrder;

  @override
  Widget build(BuildContext context) {
    final presented = session == null
        ? presentedModules(permissions)
        : portalModules(session!, permissions);
    final modules = orderModules([
      for (final module in presented)
        if (module.status != ModuleStatus.planned &&
            permissions.grantedFeatures(module).isNotEmpty)
          module,
    ], moduleOrder);

    if (modules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Text(
          'No modules assigned',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: modules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final module = modules[index];
        return _ModuleListCard(
          module: module,
          available: true,
          subtitle: module.tagline,
          onTap: () {
            Navigator.of(context).pop();
            onOpenModule(module.id);
          },
        );
      },
    );
  }
}

class _ModuleListCard extends StatelessWidget {
  const _ModuleListCard({
    required this.module,
    required this.available,
    required this.subtitle,
    required this.onTap,
  });

  final ModuleDescriptor module;
  final bool available;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = available ? module.color : context.palette.inkSecondary;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(module.icon, color: color, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        height: 1.25,
                        color: available
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                available ? Icons.chevron_right : Icons.lock_outline,
                color: available
                    ? context.palette.inkSecondary
                    : context.palette.inkSecondary.withValues(alpha: .75),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full ranked insight list, so the rotating card on the home screen is
/// not the only way to reach one that has already scrolled past.
class InsightListSheet extends StatelessWidget {
  const InsightListSheet({super.key, required this.insights, this.emptyText});

  final List<Insight> insights;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Text(
          emptyText ?? 'Nothing needs your attention right now.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: insights.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final insight = insights[i];
        final accent = toneColor(insight.tone, dark: context.isDarkTheme);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(insight.icon, color: accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.headline,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (insight.supporting != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        insight.supporting!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (insight.metric != null)
                Text(
                  insight.metric!.label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Color toneColor(InsightTone tone, {bool dark = false}) => switch (tone) {
  InsightTone.positive => dark ? AppPalette.dark.success : AppColors.success,
  InsightTone.caution =>
    dark ? const Color(0xFFF0B84D) : const Color(0xFFB77500),
  InsightTone.urgent => dark ? const Color(0xFFFCA5A5) : const Color(0xFFC62828),
  InsightTone.neutral => dark ? AppPalette.dark.brandInk : AppColors.violet,
};

/// The first profile level: identity card, Details, and Settings only.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({
    super.key,
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    required this.onSignOut,
    required this.onThemeModeChanged,
    this.moduleOrder = const [],
    this.onModuleOrderChanged,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final List<String> moduleOrder;
  final ValueChanged<List<String>>? onModuleOrderChanged;

  @override
  Widget build(BuildContext context) {
    final modules = portalModules(session, permissions);

    // Only real account data. Parent, emergency, medical and document
    // records are not held by the platform, so none are shown or invented.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _ProfileIdentityCard(session: session, modules: modules.length),
        const SizedBox(height: 16),
        _ProfileAction(
          icon: Icons.badge_outlined,
          title: 'Digital ID card',
          subtitle: 'Your campus identity',
          onTap: () => showDigitalIdCard(context, session: session),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            institutionKeepsRecordsNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.inkSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.onOpenModule,
    required this.onSignOut,
    required this.onThemeModeChanged,
    required this.modules,
    required this.moduleOrder,
    required this.onModuleOrderChanged,
  });

  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final List<ModuleDescriptor> modules;
  final List<String> moduleOrder;
  final ValueChanged<List<String>>? onModuleOrderChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      _ProfileAction(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        subtitle: 'Alerts, reminders and announcements',
        onTap: () => _openNotifications(context),
      ),
      _ProfileAction(
        icon: Icons.event_available_outlined,
        title: 'Leave applications',
        subtitle: 'Apply for leave and track approval status',
        onTap: () => _openLeaveApplications(context),
      ),
      _ProfileAction(
        icon: Icons.lock_outline,
        title: 'Privacy and security',
        subtitle: 'Password, sessions and account safety',
        onTap: () => _openPrivacySecurity(context),
      ),
      _ProfileAction(
        icon: Icons.palette_outlined,
        title: 'Customization',
        subtitle: 'Theme, appearance and display preferences',
        onTap: () => _openCustomization(
          context,
          onThemeModeChanged,
          modules,
          moduleOrder,
          onModuleOrderChanged,
        ),
      ),
      _ProfileAction(
        icon: Icons.feedback_outlined,
        title: 'Feedback',
        subtitle: 'Share feedback or raise a concern',
        onTap: () {
          Navigator.of(context).pop();
          onOpenModule('feedback');
        },
      ),
      _ProfileAction(
        icon: Icons.help_outline,
        title: 'Help and support',
        subtitle: 'Create and track a campus support ticket',
        onTap: () => _openHelpdesk(context),
      ),
      _ProfileAction(
        icon: Icons.logout,
        title: 'Sign out',
        subtitle: 'Sign out of this device and end your session',
        destructive: true,
        onTap: () {
          Navigator.of(context).pop();
          onSignOut();
        },
      ),
    ],
  );
}



void _openNotifications(BuildContext context) => showHomeSheet(
  context: context,
  title: 'Notifications',
  expand: true,
  child: const _NotificationsSheet(),
);

void openNotifications(BuildContext context) => _openNotifications(context);

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  final _notifications = <({String title, String detail, IconData icon})>[
    (
      title: 'Exam schedule updated',
      detail: 'Mid-Semester exam schedule revision is available.',
      icon: Icons.campaign_outlined,
    ),
    (
      title: 'Leave application reviewed',
      detail: 'Your personal leave request is pending approval.',
      icon: Icons.event_available_outlined,
    ),
    (
      title: 'Library pass ready',
      detail: 'Your library QR pass is available for today.',
      icon: Icons.local_library_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _notifications.isEmpty
              ? null
              : () => setState(() => _notifications.clear()),
          child: const Text('Mark all as read'),
        ),
      ),
      if (_notifications.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: Text('You are all caught up.')),
        )
      else
        for (final notification in _notifications)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(14),
              ),
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  notification.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(notification.title),
              subtitle: Text(notification.detail),
            ),
          ),
    ],
  );
}

void _openPrivacySecurity(BuildContext context) => showHomeSheet(
  context: context,
  title: 'Privacy and security',
  child: const _PrivacySecuritySheet(),
);

void openPrivacySecurity(BuildContext context) => _openPrivacySecurity(context);

class _PrivacySecuritySheet extends StatelessWidget {
  const _PrivacySecuritySheet();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    children: [
      _SecurityRow(
        icon: Icons.password_outlined,
        title: 'Password',
        subtitle: 'Change it from Settings → Password',
      ),
      _SecurityRow(
        icon: Icons.devices_outlined,
        title: 'Active sessions',
        subtitle: 'Review devices signed in to your account',
        onTap: () => _showUnavailableMessage(context, 'Session management'),
      ),
      _SecurityRow(
        icon: Icons.verified_user_outlined,
        title: 'Account safety',
        subtitle: 'Your campus account is protected by institution sign-in',
      ),
      const SizedBox(height: 12),
      Text(
        'Never share your password or verification codes with anyone.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

void _showUnavailableMessage(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature will be available soon.')));
}

void _openCustomization(
  BuildContext context,
  ValueChanged<ThemeMode> onThemeModeChanged, [
  List<ModuleDescriptor> modules = const [],
  List<String> moduleOrder = const [],
  ValueChanged<List<String>>? onModuleOrderChanged,
]) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CustomizationPage(
        modules: modules,
        moduleOrder: moduleOrder,
        onThemeModeChanged: onThemeModeChanged,
        onModuleOrderChanged: onModuleOrderChanged,
      ),
    ),
  );
}

class _CustomizationPage extends StatefulWidget {
  const _CustomizationPage({
    required this.modules,
    required this.moduleOrder,
    required this.onThemeModeChanged,
    required this.onModuleOrderChanged,
  });

  final List<ModuleDescriptor> modules;
  final List<String> moduleOrder;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<List<String>>? onModuleOrderChanged;

  @override
  State<_CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<_CustomizationPage> {
  late List<ModuleDescriptor> _modules;

  @override
  void initState() {
    super.initState();
    _modules = orderModules(widget.modules, widget.moduleOrder).toList();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final module = _modules.removeAt(oldIndex);
      _modules.insert(newIndex, module);
    });
    widget.onModuleOrderChanged?.call([
      for (final module in _modules) module.id,
    ]);
  }

  void _resetOrder() {
    setState(() => _modules = widget.modules.toList());
    widget.onModuleOrderChanged?.call(const []);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default module order restored.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Customization'),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Make SuperCampus work the way you prefer.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.brightness_6_outlined),
              ),
              title: const Text('Theme'),
              subtitle: const Text('Dark, light or follow device settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openThemePicker(context, widget.onThemeModeChanged),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Module sequence',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(onPressed: _resetOrder, child: const Text('Reset')),
            ],
          ),
          Text(
            'Drag the handle to choose which module appears first on Home.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (_modules.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No modules are currently assigned to you.'),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _modules.length,
              onReorderItem: _reorder,
              itemBuilder: (context, index) {
                final module = _modules[index];
                return Card(
                  key: ValueKey('module-order-${module.id}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    minTileHeight: 72,
                    leading: CircleAvatar(
                      backgroundColor: module.color.withValues(alpha: 0.12),
                      foregroundColor: module.color,
                      child: Icon(module.icon),
                    ),
                    title: Text(module.displayName),
                    subtitle: Text(
                      index == 0
                          ? 'Shown first on Home'
                          : 'Position ${index + 1}',
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

void _openThemePicker(
  BuildContext context,
  ValueChanged<ThemeMode> onThemeModeChanged,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final option in const [
              (ThemeMode.light, 'Light', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
              (ThemeMode.system, 'System', Icons.settings_brightness_outlined),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(option.$3),
                title: Text(option.$2),
                onTap: () {
                  onThemeModeChanged(option.$1);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

void _openHelpdesk(BuildContext context) => openHelpdesk(context);

/// Opens Help & support. Without a [repository] (no signed-in API access)
/// only the FAQ and the SuperCampus contact links are shown.
Future<void> openHelpdesk(
  BuildContext context, {
  SupportRepository? repository,
  UserSession? session,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => HelpCenterPage(repository: repository, session: session),
  ),
);

void _openLeaveApplications(BuildContext context) => showHomeSheet(
  context: context,
  title: 'Leave applications',
  expand: true,
  child: const _StudentLeaveSheet(),
);

class _StudentLeaveRequest {
  const _StudentLeaveRequest(
    this.type,
    this.start,
    this.end,
    this.reason,
    this.status,
  );
  final String type;
  final DateTime start;
  final DateTime end;
  final String reason;
  final String status;
}

class _StudentLeaveSheet extends StatefulWidget {
  const _StudentLeaveSheet();
  @override
  State<_StudentLeaveSheet> createState() => _StudentLeaveSheetState();
}

class _StudentLeaveSheetState extends State<_StudentLeaveSheet> {
  final _requests = <_StudentLeaveRequest>[
    _StudentLeaveRequest(
      'Medical leave',
      DateTime(2026, 8, 12),
      DateTime(2026, 8, 13),
      'Medical appointment',
      'Approved',
    ),
    _StudentLeaveRequest(
      'Personal leave',
      DateTime(2026, 8, 20),
      DateTime(2026, 8, 20),
      'Family commitment',
      'Pending',
    ),
  ];

  Future<void> _create() async {
    final request = await showModalBottomSheet<_StudentLeaveRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const _CreateLeaveSheet(),
    );
    if (request != null && mounted) {
      setState(() => _requests.insert(0, request));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    children: [
      FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Apply for leave'),
      ),
      const SizedBox(height: 18),
      Text(
        'REQUEST HISTORY',
        style: TextStyle(
          color: context.palette.inkSecondary,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 10),
      for (final request in _requests) ...[
        _LeaveRequestCard(request: request),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({required this.request});
  final _StudentLeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final color = request.status == 'Approved'
        ? context.palette.success
        : context.adaptive(
            light: const Color(0xFFB77500),
            dark: const Color(0xFFF0B84D),
          );
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.type,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(
                label: Text(request.status),
                labelStyle: TextStyle(color: color, fontSize: 11),
                backgroundColor: color.withValues(alpha: .1),
                side: BorderSide.none,
              ),
            ],
          ),
          Text('${_date(request.start)} – ${_date(request.end)}'),
          const SizedBox(height: 4),
          Text(request.reason, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _CreateLeaveSheet extends StatefulWidget {
  const _CreateLeaveSheet();
  @override
  State<_CreateLeaveSheet> createState() => _CreateLeaveSheetState();
}

class _CreateLeaveSheetState extends State<_CreateLeaveSheet> {
  final _reason = TextEditingController();
  var _type = 'Personal leave';
  var _start = DateTime.now().add(const Duration(days: 1));
  var _end = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool end) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: end ? _end : _start,
    );
    if (value == null) return;
    setState(() {
      if (end) {
        _end = value;
      } else {
        _start = value;
        if (_end.isBefore(value)) _end = value;
      }
    });
  }

  void _submit() {
    if (_reason.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      _StudentLeaveRequest(_type, _start, _end, _reason.text.trim(), 'Pending'),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New leave application',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: const [
                DropdownMenuItem(
                  value: 'Personal leave',
                  child: Text('Personal leave'),
                ),
                DropdownMenuItem(
                  value: 'Medical leave',
                  child: Text('Medical leave'),
                ),
                DropdownMenuItem(
                  value: 'On-duty leave',
                  child: Text('On-duty leave'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pick(false),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Start: ${_date(_start)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(true),
              icon: const Icon(Icons.event_outlined),
              label: Text('End: ${_date(_end)}'),
            ),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              child: const Text('Submit application'),
            ),
          ],
        ),
      ),
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({required this.session, required this.modules});

  final UserSession session;
  final int modules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.violetGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StudentPhoto(
                key: const ValueKey('profile-card-photo'),
                session: session,
                size: 74,
                borderColor: Colors.white.withValues(alpha: 0.72),
                borderWidth: 2,
                fallbackBackground: Colors.white.withValues(alpha: 0.18),
                fallbackForeground: Colors.white,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        session.roleLabel.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ProfileMetric(
                    label: 'Campus ID',
                    value: session.idNumber ?? 'Not assigned',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ProfileMetric(
                    label: 'Access',
                    value: '$modules modules',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

/// A person's photo from `session.photoUrl`, falling back to initials.
class StudentPhoto extends StatelessWidget {
  const StudentPhoto({
    super.key,
    required this.session,
    required this.size,
    required this.borderColor,
    this.borderWidth = 1,
    this.fallbackBackground,
    this.fallbackForeground,
  });

  final UserSession session;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final Color? fallbackBackground;
  final Color? fallbackForeground;

  @override
  Widget build(BuildContext context) {
    final url = session.photoUrl?.trim();
    final fallback = ColoredBox(
      color:
          fallbackBackground ??
          Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          initialsOf(session.displayName),
          style: TextStyle(
            color:
                fallbackForeground ??
                Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: size * 0.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFC62828);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final actionSurface = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : AppColors.moduleSoft.withValues(alpha: 0.62);
    final actionBorder = isDark
        ? AppColors.brandLavender.withValues(alpha: 0.4)
        : AppColors.brandLavender.withValues(alpha: 0.2);

    return Padding(
      padding: EdgeInsets.only(top: destructive ? 6 : 0, bottom: 10),
      child: Material(
        key: destructive
            ? const ValueKey('sign-out-action')
            : ValueKey('profile-action-$title'),
        color: destructive ? danger : actionSurface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: destructive
                    ? Colors.white.withValues(alpha: .18)
                    : actionBorder,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: destructive
                        ? Colors.white.withValues(alpha: .16)
                        : null,
                    gradient: destructive ? null : AppColors.violetGradient,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: destructive
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontWeight: destructive ? FontWeight.w700 : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: destructive
                              ? Colors.white70
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  destructive ? Icons.logout_rounded : Icons.chevron_right,
                  color: destructive
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to two initials, e.g. `Alex Johnson` -> `AJ`.
String initialsOf(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(p))
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
