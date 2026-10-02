import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Asks before signing out: a centred card with Cancel and Sign out side by
/// side. Resolves true only when the person confirms.
Future<bool> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const SignOutConfirmationCard(),
  );
  return confirmed ?? false;
}

/// Runs [onSignOut] once the person confirms in [confirmSignOut].
Future<void> signOutWithConfirmation(
  BuildContext context,
  VoidCallback onSignOut,
) async {
  if (await confirmSignOut(context)) onSignOut();
}

class SignOutConfirmationCard extends StatelessWidget {
  const SignOutConfirmationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: palette.danger,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You will need to sign in again to use SuperCampus on this '
                'device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: palette.inkSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _CardButton(
                      key: const ValueKey('sign-out-cancel'),
                      label: 'Cancel',
                      background: palette.surfaceSunken,
                      foreground: palette.ink,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardButton(
                      key: const ValueKey('sign-out-confirm'),
                      label: 'Sign out',
                      background: palette.danger,
                      foreground: Colors.white,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}
