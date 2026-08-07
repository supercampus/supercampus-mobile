import 'package:flutter/material.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../insights/data/insight.dart';

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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * (expand ? 0.85 : 0.7),
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
                    color: AppColors.border,
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
  );
}

/// Searches the catalog the user can actually see — modules by name and
/// tagline, and the features they hold a grant on. Matching a feature opens
/// its module, because that is the only place the feature exists.
class CampusSearchSheet extends StatefulWidget {
  const CampusSearchSheet({
    super.key,
    required this.permissions,
    required this.onOpenModule,
  });

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
    if (query.isEmpty) {
      return [
        for (final m in widget.permissions.visibleModules())
          _SearchResult(module: m, title: m.title, subtitle: m.tagline),
      ];
    }

    final results = <_SearchResult>[];
    for (final module in widget.permissions.visibleModules()) {
      final matchesModule =
          module.title.toLowerCase().contains(query) ||
          module.tagline.toLowerCase().contains(query);

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
            subtitle: 'in ${module.displayName}',
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
        final accent = toneColor(insight.tone);

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

Color toneColor(InsightTone tone) => switch (tone) {
  InsightTone.positive => AppColors.success,
  InsightTone.caution => const Color(0xFFB77500),
  InsightTone.urgent => const Color(0xFFC62828),
  InsightTone.neutral => AppColors.violet,
};

/// Who you are signed in as, and the way out.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({
    super.key,
    required this.session,
    required this.permissions,
    required this.onSignOut,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final modules = permissions.visibleModules();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppColors.violetGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initialsOf(session.displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      session.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Row(label: 'Role', value: session.roleLabel),
          if (session.idNumber != null)
            _Row(label: 'ID', value: session.idNumber!),
          if (session.departmentOrWard != null)
            _Row(label: 'Department', value: session.departmentOrWard!),
          _Row(label: 'Modules', value: '${modules.length} assigned'),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const ValueKey('profile-sign-out'),
            onPressed: () {
              Navigator.of(context).pop();
              onSignOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
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
