import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Whether the counter is taking orders, as a row of the profile sheet beside
/// Settings.
///
/// Opening and closing the counter is a setting of the account's counter
/// rather than a step of the queue, so it lives with the account. Only an
/// account with a counter of its own is shown the row.
class CounterOpenSwitchRow extends StatefulWidget {
  const CounterOpenSwitchRow({
    super.key,
    required this.open,
    required this.onChanged,
    this.busy = false,
  });

  final bool open;

  /// Opens (true) or closes the counter; the switch waits for it.
  final Future<void> Function(bool open) onChanged;

  /// A change started elsewhere is still in flight.
  final bool busy;

  @override
  State<CounterOpenSwitchRow> createState() => _CounterOpenSwitchRowState();
}

class _CounterOpenSwitchRowState extends State<CounterOpenSwitchRow> {
  var _pending = false;

  Future<void> _change(bool open) async {
    setState(() => _pending = true);
    try {
      await widget.onChanged(open);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final open = widget.open;
    final enabled = !_pending && !widget.busy;
    return MergeSemantics(
      child: ListTile(
        key: const ValueKey('counter-open-row'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          open ? Icons.storefront_rounded : Icons.storefront_outlined,
          color: open ? p.success : p.inkTertiary,
        ),
        title: Text(open ? 'Counter open' : 'Counter closed'),
        subtitle: Text(
          open ? 'Taking new orders' : 'Not taking new orders',
          style: TextStyle(fontSize: 12, color: p.inkSecondary),
        ),
        trailing: Switch.adaptive(
          key: const ValueKey('counter-open-switch'),
          value: open,
          onChanged: enabled ? _change : null,
        ),
        onTap: enabled ? () => _change(!open) : null,
      ),
    );
  }
}
