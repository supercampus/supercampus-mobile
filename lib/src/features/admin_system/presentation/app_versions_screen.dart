import 'package:flutter/material.dart';

import '../../../core/app_version.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_system_models.dart';
import '../data/admin_system_repository.dart';
import 'admin_system_widgets.dart';

/// App Version Management: minimum and latest supported versions per
/// platform, the store link and force update. The app compares itself with
/// this on startup and on resume.
class AppVersionsScreen extends StatefulWidget {
  const AppVersionsScreen({
    super.key,
    required this.repository,
    this.canUpdate = false,
  });

  final AdminSystemRepository repository;
  final bool canUpdate;

  @override
  State<AppVersionsScreen> createState() => _AppVersionsScreenState();
}

class _AppVersionsScreenState extends State<AppVersionsScreen> {
  late Future<List<AppVersionPolicy>> _policies = widget.repository
      .appVersions();

  void _reload() => setState(() => _policies = widget.repository.appVersions());

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<AppVersionPolicy>>(
          future: _policies,
          builder: (context, snapshot) {
            final policies = snapshot.data;
            return ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                const SystemPageHeader(
                  title: 'App Versions',
                  subtitle:
                      'Control minimum and latest required versions per platform',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(
                    'This device runs $appVersionName. Below the minimum, the '
                    'app is blocked until updated; below the latest, people '
                    'are asked to update and may skip unless force update is '
                    'on. Web is always current.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: palette.inkSecondary,
                    ),
                  ),
                ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else if (snapshot.hasError || policies == null)
                  SystemMessage(
                    icon: Icons.cloud_off_rounded,
                    title: "App versions couldn't load",
                    body: '${snapshot.error ?? ''}',
                    actionLabel: 'Try again',
                    onAction: _reload,
                  )
                else
                  for (final policy in policies)
                    _PlatformCard(
                      key: Key('app-version-${policy.platform}'),
                      policy: policy,
                      canUpdate: widget.canUpdate,
                      repository: widget.repository,
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlatformCard extends StatefulWidget {
  const _PlatformCard({
    super.key,
    required this.policy,
    required this.canUpdate,
    required this.repository,
  });

  final AppVersionPolicy policy;
  final bool canUpdate;
  final AdminSystemRepository repository;

  @override
  State<_PlatformCard> createState() => _PlatformCardState();
}

class _PlatformCardState extends State<_PlatformCard> {
  final _form = GlobalKey<FormState>();
  late AppVersionPolicy _saved = widget.policy;
  late final _latest = TextEditingController(text: widget.policy.latestVersion);
  late final _minimum = TextEditingController(
    text: widget.policy.minimumVersion,
  );
  late final _storeUrl = TextEditingController(text: widget.policy.storeUrl);
  late bool _force = widget.policy.forceUpdate;
  bool _saving = false;

  @override
  void dispose() {
    _latest.dispose();
    _minimum.dispose();
    _storeUrl.dispose();
    super.dispose();
  }

  String? _versionError(String? value) =>
      parseAppVersion(value ?? '') == null ? 'Use a version like 1.2.3' : null;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveAppVersion(
        AppVersionPolicy(
          platform: widget.policy.platform,
          latestVersion: _latest.text.trim(),
          minimumVersion: _minimum.text.trim(),
          storeUrl: _storeUrl.text.trim(),
          forceUpdate: _force,
        ),
      );
      if (!mounted) return;
      setState(() => _saved = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${saved.platformLabel} versions saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIos = widget.policy.platform == 'ios';
    final editable = widget.canUpdate && !_saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SystemCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (isIos ? palette.info : palette.success)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      isIos
                          ? Icons.phone_iphone_rounded
                          : Icons.android_rounded,
                      size: 20,
                      color: isIos ? palette.info : palette.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.policy.platformLabel,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  if (_saved.updatedAt != null)
                    Text(
                      'Updated ${formatRelative(_saved.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.inkTertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: Key('latest-${widget.policy.platform}'),
                      controller: _latest,
                      enabled: editable,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latest version',
                      ),
                      validator: _versionError,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: Key('minimum-${widget.policy.platform}'),
                      controller: _minimum,
                      enabled: editable,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum version',
                      ),
                      validator: (value) {
                        final error = _versionError(value);
                        if (error != null) return error;
                        final order = compareAppVersions(
                          value ?? '',
                          _latest.text,
                        );
                        return order != null && order > 0
                            ? 'Above the latest'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: Key('store-${widget.policy.platform}'),
                controller: _storeUrl,
                enabled: editable,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Store URL',
                  hintText: isIos
                      ? 'https://apps.apple.com/app/…'
                      : 'https://play.google.com/store/apps/details?id=…',
                ),
                validator: (value) {
                  final url = value?.trim() ?? '';
                  if (url.isEmpty) {
                    return _force
                        ? 'Add the store URL to force an update'
                        : null;
                  }
                  final uri = Uri.tryParse(url);
                  return uri == null ||
                          uri.scheme != 'https' ||
                          uri.host.isEmpty
                      ? 'Use an https:// link'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                key: Key('force-${widget.policy.platform}'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Force update'),
                subtitle: Text(
                  _force
                      ? 'Users must update to the latest version'
                      : 'Users can skip this update',
                ),
                value: _force,
                onChanged: editable
                    ? (value) => setState(() => _force = value)
                    : null,
              ),
              if (widget.canUpdate)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: Key('save-${widget.policy.platform}'),
                    onPressed: editable ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
