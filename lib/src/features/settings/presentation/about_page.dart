import 'package:flutter/material.dart';

import '../../../core/app_version.dart';
import '../../../core/theme/app_theme.dart';
import '../data/account_repository.dart';
import 'external_links.dart';
import 'settings_ui.dart';

class AboutAppPage extends StatefulWidget {
  const AboutAppPage({super.key, this.accountRepository, this.institution});

  /// Used to look up the institution name when [institution] is not given.
  final AccountRepository? accountRepository;
  final String? institution;

  @override
  State<AboutAppPage> createState() => _AboutAppPageState();
}

class _AboutAppPageState extends State<AboutAppPage> {
  late String? _institution = widget.institution;

  @override
  void initState() {
    super.initState();
    if (_institution == null && widget.accountRepository != null) {
      widget.accountRepository!.loadProfileExtras().then((extras) {
        if (mounted && extras.institution != null) {
          setState(() => _institution = extras.institution);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final year = DateTime.now().year;
    Widget external(IconData icon, String title, String url) => SettingsRow(
      icon: icon,
      title: title,
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: palette.inkTertiary,
      ),
      onTap: () => openExternalUrl(context, url),
    );

    return SettingsPageScaffold(
      title: 'About',
      children: [
        const SizedBox(height: 12),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/branding/supercampus_app_icon.png',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 88,
                height: 88,
                color: palette.brand,
                alignment: Alignment.center,
                child: Icon(Icons.school_rounded, size: 46, color: palette.onBrand),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'SuperCampus',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.ink,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version $appVersionName ($appBuildNumber)',
          key: const ValueKey('about-version'),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Academics, services and student life for your campus, in one app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkSecondary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 26),
        SettingsSection(
          dividerIndent: 16,
          children: [
            SettingsRow(title: 'Version', value: appVersionName),
            SettingsRow(title: 'Build', value: appBuildNumber),
            if (_institution != null)
              SettingsRow(title: 'Institution', value: _institution),
          ],
        ),
        SettingsSection(
          children: [
            external(Icons.privacy_tip_outlined, 'Privacy Policy', privacyPolicyUrl),
            external(
              Icons.description_outlined,
              'Terms & Conditions',
              termsUrl,
            ),
            external(
              Icons.support_agent_rounded,
              'Contact & Support',
              contactSupportUrl,
            ),
            SettingsRow(
              icon: Icons.article_outlined,
              title: 'Open-source licences',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'SuperCampus',
                applicationVersion: '$appVersionName ($appBuildNumber)',
                applicationLegalese: '© $year SuperCampus',
              ),
            ),
          ],
        ),
        Text(
          '© $year SuperCampus. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkTertiary, fontSize: 12.5),
        ),
      ],
    );
  }
}
