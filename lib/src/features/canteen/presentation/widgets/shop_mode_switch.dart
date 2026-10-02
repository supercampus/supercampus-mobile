import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/canteen_models.dart';
import 'counter_open_tile.dart';
import '../../../../core/widgets/sign_out_confirmation.dart';

/// Work / Shop, for anyone whose job is in the campus shops or offices.
///
/// Work is their counter (or, for an admin, the oversight view); Shop makes
/// them a customer of every campus store — canteen, stationery and laundry —
/// exactly as a student is.
class ShopModeSwitch extends StatelessWidget {
  const ShopModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  final CanteenStaffMode mode;
  final ValueChanged<CanteenStaffMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<CanteenStaffMode>(
        key: const ValueKey('shop-mode-switch'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: CanteenStaffMode.work,
            icon: Icon(Icons.work_outline_rounded),
            label: Text('Work'),
          ),
          ButtonSegment(
            value: CanteenStaffMode.eat,
            icon: Icon(Icons.shopping_bag_outlined),
            label: Text('Shop'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: enabled
            ? (selection) => onChanged(selection.first)
            : null,
      ),
    );
  }
}

/// The signed-in person, as the shops know them, with the Work / Shop choice,
/// the counter's open switch (for an account with a counter of its own) and
/// sign-out. Everything shown comes from the session: nothing here is filled
/// in when the account has no value for it.
///
/// [counterOpen] reads the counter's current state; the row is shown only
/// while it and [onCounterOpenChanged] are given.
Future<void> showShopAccountSheet(
  BuildContext context, {
  required String name,
  required String email,
  String? idNumber,
  String? photoUrl,
  CanteenStaffMode? mode,
  ValueChanged<CanteenStaffMode>? onModeChanged,
  VoidCallback? onOpenSettings,
  bool? Function()? counterOpen,
  Future<void> Function(bool open)? onCounterOpenChanged,
  required VoidCallback onSignOut,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Sized to its rows, scrolling when a short screen cannot hold them all.
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceRaised,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      final initials = name
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();
      final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: palette.brandSoft,
                    backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            initials.isEmpty ? '?' : initials,
                            style: TextStyle(
                              color: palette.brandInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.inkSecondary),
                          ),
                        if (idNumber != null && idNumber.trim().isNotEmpty)
                          Text(
                            idNumber,
                            style: TextStyle(
                              color: palette.inkTertiary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (mode != null && onModeChanged != null) ...[
                const SizedBox(height: 20),
                ShopModeSwitch(
                  mode: mode,
                  onChanged: (value) {
                    Navigator.of(sheetContext).pop();
                    onModeChanged(value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  mode.description,
                  style: TextStyle(color: palette.inkSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              if (counterOpen != null && onCounterOpenChanged != null)
                StatefulBuilder(
                  builder: (context, setSheetState) {
                    final open = counterOpen();
                    if (open == null) return const SizedBox.shrink();
                    return CounterOpenSwitchRow(
                      open: open,
                      onChanged: (value) async {
                        await onCounterOpenChanged(value);
                        // Re-read the counter once the change has landed.
                        if (context.mounted) setSheetState(() {});
                      },
                    );
                  },
                ),
              if (onOpenSettings != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onOpenSettings();
                  },
                ),
              // With Settings here, Sign out lives at the end of Settings.
              if (onOpenSettings == null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: palette.danger),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: palette.danger),
                  ),
                  onTap: () async {
                    if (!await confirmSignOut(sheetContext)) return;
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    onSignOut();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
