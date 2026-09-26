import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../canteen/data/backend_canteen_repository.dart';
import '../../../canteen/data/canteen_models.dart';
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
    this.currentCanteenMode,
    this.onCanteenModeChanged,
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
  final CanteenStaffMode? currentCanteenMode;
  final ValueChanged<CanteenStaffMode>? onCanteenModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _currentThemeMode = ThemeMode.system;
  late CanteenStaffMode _canteenMode =
      widget.currentCanteenMode ?? CanteenStaffMode.work;

  @override
  void initState() {
    super.initState();
    _loadCurrentThemeMode();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCanteenMode != null &&
        widget.currentCanteenMode != oldWidget.currentCanteenMode) {
      _canteenMode = widget.currentCanteenMode!;
    }
  }

  Future<void> _loadCurrentThemeMode() async {
    try {
      final preferences = SharedPreferencesAsync();
      final key =
          'supercampus.theme.${widget.session.email.trim().toLowerCase()}';
      final stored = await preferences.getString(key);
      if (stored != null) {
        final mode = ThemeMode.values.firstWhere(
          (m) => m.name == stored,
          orElse: () => ThemeMode.system,
        );
        if (mounted) {
          setState(() => _currentThemeMode = mode);
        }
      }
    } catch (_) {}
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
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
          // Profile card / Student identity bar
          _buildCard(
            color: cardColor,
            shadowColor: shadowColor,
            child: widget.session.role == UserRole.student
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isDark
                              ? const Color(0xFF323238)
                              : const Color(0xFFEDEDF0),
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
                                'Campus ID: ${widget.session.idNumber ?? 'Not assigned'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openProfile(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark
                                ? const Color(0xFF323238)
                                : const Color(0xFFEDEDF0),
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
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  textColor: textColor,
                  isDark: isDark,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _themeModeLabel(_currentThemeMode),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFC7C7CC),
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: () => _openThemeSelector(
                    context,
                    isDark,
                    textColor,
                    mutedColor,
                  ),
                ),
                if (widget.session.isCanteenOwner ||
                    widget.session.isCaptain ||
                    widget.session.isStationeryOwner) ...[
                  _buildDivider(dividerColor),
                  _SettingsTile(
                    icon: Icons.storefront_outlined,
                    title: widget.session.isStationeryOwner
                        ? 'Stationery mode'
                        : 'Canteen mode',
                    textColor: textColor,
                    isDark: isDark,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _canteenMode == CanteenStaffMode.work
                              ? 'Work mode'
                              : 'Eat mode',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFC7C7CC),
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () => _openCanteenModeSelector(
                      context,
                      isDark,
                      textColor,
                      mutedColor,
                    ),
                  ),
                ],
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
                  onTap: () =>
                      _openAbout(context, isDark, textColor, mutedColor),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Help/FAQ',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => openHelpdesk(context),
                ),
                if (widget.session.role != UserRole.student) ...[
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
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Group 3: Legal & Account Management
          _buildCard(
            color: cardColor,
            shadowColor: shadowColor,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  textColor: textColor,
                  isDark: isDark,
                  trailing: const Icon(
                    Icons.open_in_new_rounded,
                    color: Color(0xFFC7C7CC),
                    size: 18,
                  ),
                  onTap: () => _openWebUrl('https://supercampus.ai/privacy'),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  textColor: textColor,
                  isDark: isDark,
                  trailing: const Icon(
                    Icons.open_in_new_rounded,
                    color: Color(0xFFC7C7CC),
                    size: 18,
                  ),
                  onTap: () => _openWebUrl('https://supercampus.ai/terms'),
                ),
                if (widget.session.role != UserRole.student) ...[
                  _buildDivider(dividerColor),
                  _SettingsTile(
                    icon: Icons.person_remove_outlined,
                    title: 'Delete Account (Web Request)',
                    textColor: textColor,
                    isDark: isDark,
                    trailing: const Icon(
                      Icons.open_in_new_rounded,
                      color: Color(0xFFC7C7CC),
                      size: 18,
                    ),
                    onTap: () =>
                        _openWebUrl('https://supercampus.ai/delete-account'),
                  ),
                ],
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Contact & Support',
                  textColor: textColor,
                  isDark: isDark,
                  trailing: const Icon(
                    Icons.open_in_new_rounded,
                    color: Color(0xFFC7C7CC),
                    size: 18,
                  ),
                  onTap: () => _openWebUrl('https://supercampus.ai/contact'),
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

  void _openCanteenModeSelector(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF222226) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Canteen mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose whether you are actively running counter operations or browsing as a customer.',
                  style: TextStyle(
                    fontSize: 13,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _canteenMode == CanteenStaffMode.work
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : (isDark
                              ? const Color(0xFF2A2A2E)
                              : const Color(0xFFF2F2F5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: _canteenMode == CanteenStaffMode.work
                          ? AppColors.primary
                          : mutedColor,
                    ),
                  ),
                  title: Text(
                    'Work mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    'Manage live orders, counter controls, and menu items',
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  trailing: _canteenMode == CanteenStaffMode.work
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _canteenMode = CanteenStaffMode.work);
                    widget.onCanteenModeChanged?.call(CanteenStaffMode.work);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _canteenMode == CanteenStaffMode.eat
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : (isDark
                              ? const Color(0xFF2A2A2E)
                              : const Color(0xFFF2F2F5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.restaurant_outlined,
                      color: _canteenMode == CanteenStaffMode.eat
                          ? AppColors.primary
                          : mutedColor,
                    ),
                  ),
                  title: Text(
                    'Eat mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    'Browse student menu, order food, and pay from wallet',
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  trailing: _canteenMode == CanteenStaffMode.eat
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _canteenMode = CanteenStaffMode.eat);
                    widget.onCanteenModeChanged?.call(CanteenStaffMode.eat);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openThemeSelector(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF222226) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Choose Theme',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildThemeOptionTile(
                  title: 'Light',
                  subtitle: 'Always use light theme',
                  icon: Icons.light_mode_outlined,
                  mode: ThemeMode.light,
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                _buildThemeOptionTile(
                  title: 'Dark',
                  subtitle: 'Always use dark theme',
                  icon: Icons.dark_mode_outlined,
                  mode: ThemeMode.dark,
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                _buildThemeOptionTile(
                  title: 'System',
                  subtitle: 'Follow device system preference',
                  icon: Icons.brightness_auto_outlined,
                  mode: ThemeMode.system,
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool isDark,
    required Color textColor,
    required Color mutedColor,
  }) {
    final isSelected = _currentThemeMode == mode;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2C2C32) : const Color(0xFFF1F2F6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primary : textColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primary : textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: mutedColor),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 22,
            )
          : null,
      onTap: () {
        Navigator.of(context).pop();
        setState(() => _currentThemeMode = mode);
        widget.onThemeModeChanged(mode);
      },
    );
  }

  void _openProfile(BuildContext context) {
    showHomeSheet(
      context: context,
      title: widget.session.role == UserRole.student
          ? 'Profile Details'
          : 'Profile',
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

  Future<void> _openWebUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Ignored or handled gracefully
    }
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
