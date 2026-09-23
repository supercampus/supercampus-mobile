import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../canteen/data/backend_canteen_repository.dart';
import '../../../canteen/presentation/transaction_pin_sheet.dart';
import 'home_sheets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    required this.onSignOut,
    required this.onThemeModeChanged,
    required this.modules,
    required this.moduleOrder,
    this.onModuleOrderChanged,
    this.accessTokenProvider,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final List<ModuleDescriptor> modules;
  final List<String> moduleOrder;
  final ValueChanged<List<String>>? onModuleOrderChanged;
  final AccessTokenProvider? accessTokenProvider;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF141416) : const Color(0xFFF7F7F9);
    final cardColor = isDark ? const Color(0xFF222226) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = const Color(0xFF8E8E93);
    final dividerColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2);
    final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

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
              shadowColor: shadowColor,
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
          'Settings',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          // Profile card
          _buildCard(
            color: cardColor,
            shadowColor: shadowColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openProfile(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? const Color(0xFF323238) : const Color(0xFFEDEDF0),
                      backgroundImage: widget.session.photoUrl != null &&
                              widget.session.photoUrl!.isNotEmpty
                          ? NetworkImage(widget.session.photoUrl!)
                          : null,
                      child: widget.session.photoUrl == null ||
                              widget.session.photoUrl!.isEmpty
                          ? Icon(Icons.person, color: mutedColor, size: 26)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.session.departmentOrWard ??
                                widget.session.role.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: const Color(0xFFC7C7CC),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // "Other settings" header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Other settings',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
          ),

          // Group 1
          _buildCard(
            color: cardColor,
            shadowColor: shadowColor,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile details',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => _openProfile(context),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Password',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => openPrivacySecurity(context),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.dialpad_rounded,
                  title: 'Transaction PIN',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => _openChangePinPage(context),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => openNotifications(context),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark mode',
                  textColor: textColor,
                  isDark: isDark,
                  trailing: Transform.scale(
                    scale: 0.85,
                    child: CupertinoSwitch(
                      value: isDark,
                      activeTrackColor: const Color(0xFF5E5CE6),
                      onChanged: (val) {
                        widget.onThemeModeChanged(
                          val ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Group 2
          _buildCard(
            color: cardColor,
            shadowColor: shadowColor,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About application',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => _openAbout(context, isDark, textColor, mutedColor),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Help/FAQ',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => openHelpdesk(context),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Deactivate my account',
                  textColor: const Color(0xFFE53935),
                  iconColor: const Color(0xFFE53935),
                  isDark: isDark,
                  onTap: () => _confirmDeactivate(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Color color,
    required Color shadowColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }

  Widget _buildDivider(Color dividerColor) {
    return Divider(
      height: 1,
      thickness: 1,
      color: dividerColor,
      indent: 52,
    );
  }

  void _openProfile(BuildContext context) {
    showHomeSheet(
      context: context,
      title: 'Profile',
      expand: true,
      child: ProfileSheet(
        session: widget.session,
        permissions: widget.permissions,
        onOpenModule: widget.onOpenModule,
        onSignOut: widget.onSignOut,
        onThemeModeChanged: widget.onThemeModeChanged,
        moduleOrder: widget.moduleOrder,
        onModuleOrderChanged: widget.onModuleOrderChanged,
      ),
    );
  }

  Future<void> _openChangePinPage(BuildContext context) async {
    final provider = widget.accessTokenProvider;
    if (provider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN change is not available')),
      );
      return;
    }
    const baseUrl = String.fromEnvironment(
      'SUPERCAMPUS_API_BASE_URL',
      defaultValue: 'https://api.supercampus.ai',
    );
    final repo = BackendCanteenRepository(
      baseUrl: baseUrl,
      accessTokenProvider: provider,
    );

    // Show change PIN sheet; hasHint = false for now (we don't track it here).
    if (!context.mounted) return;
    final result = await showChangePinSheet(context, hasHint: true);
    if (result == null || !context.mounted) return;

    try {
      await repo.changeWalletPin(
        newPinHash: result.newPinHash,
        method: result.method,
        currentPinHash: result.currentPinHash,
        hint: result.hint,
        password: result.password,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction PIN updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }


  void _openAbout(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF222226) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF38383E) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 34,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'SuperCampus',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0 (Build 2026.09)',
                style: TextStyle(fontSize: 13, color: mutedColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Unified Campus Operating System for Academics, Services & Student Life.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: mutedColor, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Deactivate Account'),
        content: const Text(
          'Are you sure you want to deactivate your account or sign out from this device? You will need to sign in again to access campus services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              widget.onSignOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
            ),
            child: const Text(
              'Sign out / Deactivate',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.isDark,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Color textColor;
  final Color? iconColor;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        iconColor ?? (isDark ? Colors.white : const Color(0xFF1C1C1E));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: effectiveIconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC7C7CC),
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }
}
