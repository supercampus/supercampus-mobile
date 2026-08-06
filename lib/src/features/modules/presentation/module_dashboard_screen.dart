import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/focus_carousel.dart';
import '../../authentication/data/auth_repository.dart';
import '../../insights/presentation/insight_dashboard.dart';

/// One portal for every user. The card list is a projection of
/// [EffectivePermissions] over [ModuleCatalog] — there are no role checks in
/// this file. Granting a module in the admin console makes a card appear;
/// changing the granted actions changes the badge and the chips.
class ModuleDashboardScreen extends StatefulWidget {
  const ModuleDashboardScreen({
    super.key,
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    required this.onSignOut,
    this.dashboard,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;

  /// Fills the upper half of the screen. Drop your dashboard widget in here;
  /// a placeholder is shown until then.
  final Widget? dashboard;

  @override
  State<ModuleDashboardScreen> createState() => _ModuleDashboardScreenState();
}

class _ModuleDashboardScreenState extends State<ModuleDashboardScreen> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final modules = widget.permissions.visibleModules();
    final focused = modules.isEmpty
        ? AppColors.primary
        : modules[_current.clamp(0, modules.length - 1)].color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SuperCampus'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _Header(
                  session: widget.session,
                  moduleCount: modules.length,
                  accent: focused,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final height = constraints.maxHeight;
                      return Column(
                        children: [
                          SizedBox(
                            height: height * 0.36,
                            child:
                                widget.dashboard ??
                                InsightDashboard(
                                  permissions: widget.permissions,
                                ),
                          ),
                          // Leaves the remaining ~12% below the carousel so it
                          // sits clear of the bottom edge.
                          SizedBox(
                            height: height * 0.52,
                            child: modules.isEmpty
                                ? const _NoAccessState()
                                : FocusCarousel(
                                    itemCount: modules.length,
                                    itemHeightFraction: 0.80,
                                    itemGap: 10,
                                    indicatorColor: focused,
                                    onPageChanged: (index) =>
                                        setState(() => _current = index),
                                    itemBuilder: (context, index, focus) =>
                                        _ModuleCard(
                                          module: modules[index],
                                          permissions: widget.permissions,
                                          focus: focus,
                                          onOpen: () => widget.onOpenModule(
                                            modules[index].id,
                                          ),
                                        ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.moduleCount,
    required this.accent,
  });

  final UserSession session;
  final int moduleCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Good ${_dayPart()}, '),
                TextSpan(
                  text: session.displayName.split(' ').first,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            moduleCount == 0
                ? '${session.roleLabel} · no modules assigned yet'
                : '${session.roleLabel} · $moduleCount modules',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.permissions,
    required this.focus,
    required this.onOpen,
  });

  final ModuleDescriptor module;
  final EffectivePermissions permissions;

  /// 1.0 when centred, 0.0 for the neighbouring cards.
  final double focus;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final level = permissions.accessLevel(module.id);
    final scope = permissions.scopeFor(module.id);
    final features = permissions.grantedFeatures(module);
    final ready = module.status != ModuleStatus.planned;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_shade(module.color, 1.45), _shade(module.color, 0.74)],
        ),
        boxShadow: [
          BoxShadow(
            color: module.color.withValues(alpha: 0.10 + 0.24 * focus),
            blurRadius: 30,
            offset: Offset(0, 10 + 8 * focus),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  module.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _AccessBadge(level: level),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.tagline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Scope · ${scope.label}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final feature in features)
                        _FeatureChip(
                          label: feature.label,
                          actions: permissions.grantedActions(
                            module.id,
                            feature,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: ValueKey('open-module-${module.id}'),
              onPressed: ready ? onOpen : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _shade(module.color, 0.8),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.28),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                ready ? Icons.arrow_forward : Icons.schedule_outlined,
                size: 18,
              ),
              label: Text(ready ? 'Open module' : 'Coming soon'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightness shift in HSL, so each module's gradient stays on its own hue
/// instead of washing out toward grey the way an alpha blend would.
Color _shade(Color color, double factor) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
}

class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.level});

  final AccessLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.actions});

  final String label;
  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label · ${actions.join(', ')}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NoAccessState extends StatelessWidget {
  const _NoAccessState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              'No modules assigned',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your administrator has not granted access to any '
              'campus service yet.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
