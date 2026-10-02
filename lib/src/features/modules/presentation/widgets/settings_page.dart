import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sign_out_confirmation.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../canteen/data/backend_canteen_repository.dart';
import '../../../canteen/data/canteen_models.dart';
import '../../../canteen/data/wallet_pin_repository.dart';
import '../../../canteen/presentation/transaction_pin_sheet.dart';
import '../../../settings/data/account_repository.dart';
import '../../../settings/data/support_repository.dart';
import '../../../settings/presentation/about_page.dart';
import '../../../settings/presentation/change_password_page.dart';
import '../../../settings/presentation/help_center_page.dart';
import '../../../settings/presentation/help_inbox_page.dart';
import '../../../settings/presentation/profile_details_page.dart';
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
    this.apiBaseUrl,
    this.accountRepository,
    this.supportRepository,
    this.walletPinRepository,
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

  /// The resolved backend (app.dart `_resolvedBackendBaseUrl`). Null in mock
  /// builds, where the account features explain they are unavailable.
  final String? apiBaseUrl;

  /// Overrides for tests; built from [apiBaseUrl] and [accessTokenProvider]
  /// when absent.
  final AccountRepository? accountRepository;
  final SupportRepository? supportRepository;
  final WalletPinRepository? walletPinRepository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Matches the app's default (app.dart `_loadThemeMode`): an account with no
  // saved choice renders light, so the picker must say Light, not System.
  ThemeMode _currentThemeMode = ThemeMode.light;
  late CanteenStaffMode _canteenMode =
      widget.currentCanteenMode ?? CanteenStaffMode.work;

  late final AccountRepository? _accountRepository =
      widget.accountRepository ??
      _withBackend(
        (baseUrl, tokens) => BackendAccountRepository(
          baseUrl: baseUrl,
          accessTokenProvider: tokens,
        ),
      );
  late final SupportRepository? _supportRepository =
      widget.supportRepository ??
      _withBackend(
        (baseUrl, tokens) => BackendSupportRepository(
          baseUrl: baseUrl,
          accessTokenProvider: tokens,
        ),
      );
  late final WalletPinRepository? _walletPinRepository =
      widget.walletPinRepository ??
      _withBackend(
        (baseUrl, tokens) => BackendCanteenRepository(
          baseUrl: baseUrl,
          accessTokenProvider: tokens,
        ),
      );

  T? _withBackend<T>(T Function(String baseUrl, AccessTokenProvider) build) {
    final baseUrl = widget.apiBaseUrl?.trim() ?? '';
    final tokens = widget.accessTokenProvider;
    if (baseUrl.isEmpty || tokens == null) return null;
    try {
      return build(baseUrl, tokens);
    } catch (_) {
      return null;
    }
  }

  void _showUnavailable(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature needs a connection to your campus server.'),
      ),
    );
  }

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
          orElse: () => ThemeMode.light,
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
        centerTitle: false,
        titleSpacing: 8,
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
                ? InkWell(
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
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFC7C7CC),
                          size: 22,
                        ),
                      ],
                    ),
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
                  onTap: () => _openChangePassword(context),
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
                // The host offers Work / Shop to everyone with a job; it
                // passes the handler only for them.
                if (widget.onCanteenModeChanged != null) ...[
                  _buildDivider(dividerColor),
                  _SettingsTile(
                    icon: Icons.storefront_outlined,
                    title: 'Work / Shop',
                    textColor: textColor,
                    isDark: isDark,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _canteenMode.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.palette.brandInk,
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
                  onTap: () => _openAbout(context),
                ),
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Help & support',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => openHelpdesk(
                    context,
                    repository: _supportRepository,
                    session: widget.session,
                  ),
                ),
                if (_supportRepository != null &&
                    receivesHelpRequests(widget.session)) ...[
                  _buildDivider(dividerColor),
                  _SettingsTile(
                    icon: Icons.inbox_outlined,
                    title: 'Help requests inbox',
                    textColor: textColor,
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            HelpInboxPage(repository: _supportRepository),
                      ),
                    ),
                  ),
                ],
                if (widget.session.role != UserRole.student) ...[
                  _buildDivider(dividerColor),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Deactivate my account',
                    textColor: context.adaptive(
                      light: const Color(0xFFE53935),
                      dark: const Color(0xFFFF7A75),
                    ),
                    iconColor: context.adaptive(
                      light: const Color(0xFFE53935),
                      dark: const Color(0xFFFF7A75),
                    ),
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
                // Every user, students included, must be able to find how to
                // delete their account from inside the app (Google Play policy).
                _buildDivider(dividerColor),
                _SettingsTile(
                  icon: Icons.person_remove_outlined,
                  title: 'Delete Account',
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

          const SizedBox(height: 24),

          // Sign out, last on the page, behind a confirmation.
          _buildCard(
            color: cardColor,
            shadowColor: shadowColor,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('settings-sign-out'),
                onTap: () => _signOut(context),
                child: SizedBox(
                  height: 54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: context.palette.danger,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.palette.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                  'Work / Shop',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Work is your job. Shop lets you buy from the canteen, stationery and laundry like any student.',
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
                          ? context.palette.brandInk.withValues(alpha: 0.12)
                          : (isDark
                              ? const Color(0xFF2A2A2E)
                              : const Color(0xFFF2F2F5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: _canteenMode == CanteenStaffMode.work
                          ? context.palette.brandInk
                          : mutedColor,
                    ),
                  ),
                  title: Text(
                    'Work',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    CanteenStaffMode.work.description,
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  trailing: _canteenMode == CanteenStaffMode.work
                      ? Icon(Icons.check_circle, color: context.palette.brandInk)
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
                          ? context.palette.brandInk.withValues(alpha: 0.12)
                          : (isDark
                              ? const Color(0xFF2A2A2E)
                              : const Color(0xFFF2F2F5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: _canteenMode == CanteenStaffMode.eat
                          ? context.palette.brandInk
                          : mutedColor,
                    ),
                  ),
                  title: Text(
                    'Shop',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    CanteenStaffMode.eat.description,
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  trailing: _canteenMode == CanteenStaffMode.eat
                      ? Icon(Icons.check_circle, color: context.palette.brandInk)
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
              ? context.palette.brandInk.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2C2C32) : const Color(0xFFF1F2F6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? context.palette.brandInk : textColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? context.palette.brandInk : textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: mutedColor),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              color: context.palette.brandInk,
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
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProfileDetailsPage(
          session: widget.session,
          accountRepository: _accountRepository,
        ),
      ),
    );
  }

  void _openChangePassword(BuildContext context) {
    final repository = _accountRepository;
    if (repository == null) {
      _showUnavailable('Changing your password');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangePasswordPage(
          repository: repository,
          email: widget.session.email,
        ),
      ),
    );
  }

  Future<void> _openChangePinPage(BuildContext context) async {
    final repository = _walletPinRepository;
    if (repository == null) {
      _showUnavailable('Your transaction PIN');
      return;
    }
    // The sheet loads hasPin / hasPinHint itself, then offers Set PIN or
    // Change PIN and reports every server refusal inline.
    await showWalletPinSheet(context, repository: repository);
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AboutAppPage(accountRepository: _accountRepository),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    if (!await confirmSignOut(context)) return;
    if (!context.mounted) return;
    Navigator.of(context).pop();
    widget.onSignOut();
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
              foregroundColor: context.adaptive(
                light: const Color(0xFFE53935),
                dark: const Color(0xFFFF7A75),
              ),
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

  /// Opens a supercampus.ai page. `canLaunchUrl` is deliberately not used as a
  /// gate: it reports false in several mobile browsers and installed web apps
  /// even though the launch itself works, which made these links do nothing.
  Future<void> _openWebUrl(String url) async {
    final uri = Uri.parse(url);
    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t open ${uri.host}${uri.path}')),
      );
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
