import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../../modules/presentation/widgets/home_sheets.dart' show StudentPhoto;
import '../data/account_repository.dart';
import 'settings_ui.dart';

/// Shown in place of parent, emergency, medical and document records, which
/// the platform does not hold. Never replace this with sample data.
const institutionKeepsRecordsNote =
    'Parent, emergency and medical details are kept by your institution '
    'office.';

/// The signed-in person's real profile: what the session carries, plus the
/// institution, programme, year and residency when the server has them.
class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({
    super.key,
    required this.session,
    this.accountRepository,
  });

  final UserSession session;

  /// Loads the optional extras. Without one, the page shows session data only.
  final AccountRepository? accountRepository;

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  ProfileExtras _extras = ProfileExtras.empty;
  late bool _loading = widget.accountRepository != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = widget.accountRepository;
    if (repository == null) return;
    final extras = await repository.loadProfileExtras();
    if (!mounted) return;
    setState(() {
      _extras = extras;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final palette = context.palette;
    final department = _nonEmpty(session.departmentOrWard);
    final section = _nonEmpty(session.sectionId);
    final idNumber = _nonEmpty(session.idNumber);
    final academic = <Widget>[
      if (department != null)
        SettingsFactRow(label: 'Department', value: department),
      if (section != null) SettingsFactRow(label: 'Section', value: section),
      if (_extras.programme case final programme?)
        SettingsFactRow(label: 'Programme', value: programme),
      if (_extras.academicYear case final year?)
        SettingsFactRow(label: 'Academic year', value: year),
    ];
    final residence = <Widget>[
      if (_extras.residency case final residency?)
        SettingsFactRow(
          label: 'Residency',
          value: residency == 'hosteller'
              ? 'Hosteller'
              : residency == 'day_scholar'
              ? 'Day scholar'
              : residency,
        ),
      if (_extras.isHosteller) ...[
        if (_extras.hostel case final hostel?)
          SettingsFactRow(label: 'Hostel', value: hostel),
        if (_extras.block case final block?)
          SettingsFactRow(label: 'Block', value: block),
        if (_extras.room case final room?)
          SettingsFactRow(label: 'Room', value: room),
      ],
    ];

    return SettingsPageScaffold(
      title: 'Profile',
      children: [
        const SizedBox(height: 8),
        Center(
          child: StudentPhoto(
            key: const ValueKey('profile-details-photo'),
            session: session,
            size: 96,
            borderColor: palette.border,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          session.displayName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          [
            session.roleLabel,
            if (_extras.institution case final institution?) institution,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkSecondary, fontSize: 14.5),
        ),
        const SizedBox(height: 22),
        SettingsSection(
          header: 'Account',
          dividerIndent: 16,
          children: [
            SettingsFactRow(label: 'Email', value: session.email, copyable: true),
            SettingsFactRow(
              label: 'Campus ID',
              value: idNumber ?? 'Not assigned',
              copyable: idNumber != null,
            ),
          ],
        ),
        if (academic.isNotEmpty)
          SettingsSection(
            header: 'Academic',
            dividerIndent: 16,
            children: academic,
          ),
        if (residence.isNotEmpty)
          SettingsSection(
            header: 'Residence',
            dividerIndent: 16,
            children: residence,
          ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.inkTertiary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading academic details…',
                  style: TextStyle(color: palette.inkSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        SettingsSection(
          footer:
              '$institutionKeepsRecordsNote Your photo and details are managed '
              'by your institution — to correct something, use Help → Ask for '
              'help.',
          children: [
            SettingsRow(
              icon: Icons.badge_outlined,
              title: 'Digital ID card',
              onTap: () => showDigitalIdCard(
                context,
                session: session,
                institution: _extras.institution,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String? _nonEmpty(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// A digital ID card made only of real session data.
Future<void> showDigitalIdCard(
  BuildContext context, {
  required UserSession session,
  String? institution,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => DigitalIdCard(session: session, institution: institution),
  );
}

class DigitalIdCard extends StatelessWidget {
  const DigitalIdCard({super.key, required this.session, this.institution});

  final UserSession session;
  final String? institution;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final idNumber = _nonEmpty(session.idNumber);
    final department = _nonEmpty(session.departmentOrWard);
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (institution != null)
                  Text(
                    institution!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.brandInk,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                const SizedBox(height: 14),
                Center(
                  child: StudentPhoto(
                    key: const ValueKey('digital-id-photo'),
                    session: session,
                    size: 104,
                    borderColor: palette.brandInk,
                    borderWidth: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  session.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  session.roleLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.inkSecondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                line('Campus ID', idNumber ?? 'Not assigned'),
                if (department != null) line('Department', department),
                line('Email', session.email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
