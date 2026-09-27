import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Building blocks for the Settings screens: a page with a quiet canvas and
/// inset grouped lists, the way iOS Settings reads. Every colour comes from
/// [AppPalette], so light and dark both look intentional.

class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.bottom,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  /// Pinned below the list, above the keyboard (for a primary button).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.chevron_left_rounded, color: palette.ink, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: palette.ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: children,
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// An inset, rounded group of rows with an optional caption above and a
/// footnote below.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.dividerIndent = 52,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 0.6,
            indent: dividerIndent,
            color: palette.divider,
          ),
        );
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Semantics(
                header: true,
                child: Text(
                  header!,
                  style: TextStyle(
                    color: palette.inkSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  color: palette.inkSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row in a [SettingsSection].
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;

  /// Right-aligned secondary text, e.g. the current setting.
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Defaults to true when the row is tappable and has no [trailing].
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final titleColor = destructive ? palette.danger : palette.ink;
    final chevron = showChevron ?? (onTap != null && trailing == null);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 22,
                  color: destructive ? palette.danger : palette.brandInk,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.inkSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.inkTertiary,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A label/value row for read-only facts, stacked so long values (emails,
/// programme names) never truncate. [copyValue] adds a copy button.
class SettingsFactRow extends StatelessWidget {
  const SettingsFactRow({
    super.key,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, copyable ? 4 : 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: palette.inkSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () => _copy(context),
              icon: Icon(
                Icons.copy_rounded,
                size: 19,
                color: palette.brandInk,
              ),
            ),
        ],
      ),
    );
  }
}

enum InlineMessageTone { error, success, info }

/// A calm, inline status line — errors sit next to what caused them rather
/// than in a transient snackbar.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.tone = InlineMessageTone.error,
  });

  final String message;
  final InlineMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (fg, bg, icon) = switch (tone) {
      InlineMessageTone.error => (
        palette.danger,
        palette.dangerSoft,
        Icons.error_outline_rounded,
      ),
      InlineMessageTone.success => (
        palette.success,
        palette.successSoft,
        Icons.check_circle_outline_rounded,
      ),
      InlineMessageTone.info => (
        palette.info,
        palette.infoSoft,
        Icons.info_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontSize: 13.5, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width primary action with a built-in busy state.
class SettingsPrimaryButton extends StatelessWidget {
  const SettingsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: palette.onBrand,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.inkDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: palette.inkSecondary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Text field styled for a grouped section: borderless, label above.
class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    required this.label,
    this.fieldKey,
    this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final String? hint;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        obscureText: obscure,
        autofillHints: autofillHints,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        maxLength: maxLength,
        maxLines: obscure ? 1 : maxLines,
        minLines: obscure ? null : minLines,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        textCapitalization: textCapitalization,
        style: TextStyle(color: palette.ink, fontSize: 15.5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          errorMaxLines: 3,
          filled: false,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          counterStyle: TextStyle(color: palette.inkTertiary, fontSize: 11),
          labelStyle: TextStyle(color: palette.inkSecondary),
          floatingLabelStyle: TextStyle(color: palette.brandInk),
          hintStyle: TextStyle(color: palette.inkTertiary),
          suffixIcon: onToggleObscure == null
              ? null
              : IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: palette.inkSecondary,
                    size: 20,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Status chip that pairs text with an icon, so colour is never the only
/// signal.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
