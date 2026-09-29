import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_version.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_system_models.dart';
import '../data/app_version_repository.dart';

typedef StoreLauncher = Future<bool> Function(Uri uri);

Future<bool> _openStore(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Compares the running app with the administrator's version policy at
/// startup and on every resume.
///
/// Below the minimum version, or below the latest with force update on, the
/// app is replaced by a blocking screen that links to the store. Below the
/// latest otherwise, a dismissible prompt appears once per version. Web builds
/// are always current, and desktop builds have no store, so both skip the
/// check. A failed check never blocks: the app keeps working offline.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.source,
    required this.child,
    this.currentVersion = appVersionName,
    this.platform,
    this.isWeb = kIsWeb,
    this.openStore = _openStore,
  });

  /// Null disables the check (mock and test builds).
  final AppVersionSource? source;
  final Widget child;
  final String currentVersion;

  /// `android` or `ios`; defaults to the running platform.
  final String? platform;
  final bool isWeb;
  final StoreLauncher openStore;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  AppVersionPolicy? _policy;
  AppUpdateRequirement _requirement = AppUpdateRequirement.none;
  String? _promptedFor;
  bool _checking = false;

  String? get _platform =>
      widget.platform ??
      switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };

  bool get _enabled =>
      !widget.isWeb && widget.source != null && _platform != null;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (!_enabled || _checking) return;
    _checking = true;
    try {
      final policy = await widget.source!.fetch(_platform!);
      if (!mounted) return;
      final requirement = evaluateAppUpdate(widget.currentVersion, policy);
      setState(() {
        _policy = policy;
        _requirement = requirement;
      });
      if (requirement == AppUpdateRequirement.required) {
        // Pages pushed over home would otherwise stay usable above the block.
        Navigator.maybeOf(context)?.popUntil((route) => route.isFirst);
      }
      if (requirement == AppUpdateRequirement.recommended &&
          _promptedFor != policy.latestVersion) {
        _promptedFor = policy.latestVersion;
        WidgetsBinding.instance.addPostFrameCallback((_) => _prompt(policy));
      }
    } catch (_) {
      // Fail open: an unreachable policy must not lock anyone out.
    } finally {
      _checking = false;
    }
  }

  Future<void> _update(AppVersionPolicy policy) async {
    final uri = Uri.tryParse(policy.storeUrl.trim());
    if (uri == null || !uri.hasScheme) return;
    await widget.openStore(uri);
  }

  Future<void> _prompt(AppVersionPolicy policy) async {
    if (!mounted || _requirement != AppUpdateRequirement.recommended) return;
    final hasStore = policy.storeUrl.trim().isNotEmpty;
    final update = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('app-update-prompt'),
        title: const Text('Update available'),
        content: Text(
          'SuperCampus ${policy.latestVersion} is available. '
          "You're on ${widget.currentVersion}.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          if (hasStore)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Update'),
            ),
        ],
      ),
    );
    if (update == true) await _update(policy);
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy;
    if (_requirement != AppUpdateRequirement.required || policy == null) {
      return widget.child;
    }
    return _UpdateRequiredScreen(
      policy: policy,
      currentVersion: widget.currentVersion,
      onUpdate: () => _update(policy),
      onCheckAgain: _check,
    );
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen({
    required this.policy,
    required this.currentVersion,
    required this.onUpdate,
    required this.onCheckAgain,
  });

  final AppVersionPolicy policy;
  final String currentVersion;
  final VoidCallback onUpdate;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasStore = policy.storeUrl.trim().isNotEmpty;
    final store = policy.platform == 'ios' ? 'App Store' : 'Play Store';
    return Scaffold(
      key: const Key('app-update-required'),
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  size: 48,
                  color: palette.brandInk,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Update required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This version of SuperCampus ($currentVersion) is no longer '
                'supported. Update to ${policy.latestVersion} to keep using '
                'the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: palette.inkSecondary,
                ),
              ),
              if (!hasStore) ...[
                const SizedBox(height: 12),
                Text(
                  'Open the $store and update SuperCampus.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: palette.inkTertiary),
                ),
              ],
              const Spacer(flex: 3),
              if (hasStore)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    key: const Key('app-update-open-store'),
                    onPressed: onUpdate,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Update from the $store',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              TextButton(
                onPressed: onCheckAgain,
                child: const Text('Check again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
