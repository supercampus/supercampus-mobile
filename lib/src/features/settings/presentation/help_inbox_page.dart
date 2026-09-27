import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/settings_api.dart';
import '../data/support_repository.dart';
import 'settings_ui.dart';
import 'support_ticket_widgets.dart';

/// Help requests routed to a role the signed-in user holds. The server
/// decides what appears here; staff mark requests In progress or Resolved,
/// optionally with a reply the requester sees.
class HelpInboxPage extends StatefulWidget {
  const HelpInboxPage({super.key, required this.repository});

  final SupportRepository repository;

  @override
  State<HelpInboxPage> createState() => _HelpInboxPageState();
}

class _HelpInboxPageState extends State<HelpInboxPage> {
  var _openOnly = true;
  List<SupportTicket>? _tickets;
  String? _error;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await widget.repository.inbox(
        status: _openOnly ? SupportTicketStatus.open : null,
      );
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is SettingsApiException
            ? error.message
            : 'Help requests could not be loaded.';
      });
    }
  }

  Future<void> _update(SupportTicket ticket, SupportTicketStatus status) async {
    final updated = await showModalBottomSheet<SupportTicket>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _UpdateTicketSheet(
        repository: widget.repository,
        ticket: ticket,
        status: status,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _tickets = [
        for (final item in _tickets ?? const <SupportTicket>[])
          if (item.id == ticket.id) updated else item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tickets = _tickets;
    return SettingsPageScaffold(
      title: 'Help requests',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh_rounded, color: palette.ink),
        ),
      ],
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Open')),
            ButtonSegment(value: false, label: Text('All')),
          ],
          selected: {_openOnly},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            setState(() => _openOnly = value.first);
            _load();
          },
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          InlineMessage(message: _error!),
          const SizedBox(height: 12),
        ],
        if (tickets == null && _loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (tickets != null && tickets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 40, color: palette.inkTertiary),
                const SizedBox(height: 10),
                Text(
                  _openOnly ? 'No open requests.' : 'No requests yet.',
                  style: TextStyle(color: palette.inkSecondary, fontSize: 15),
                ),
              ],
            ),
          )
        else if (tickets != null)
          SettingsSection(
            dividerIndent: 16,
            children: [
              for (final ticket in tickets)
                SupportTicketTile(
                  ticket: ticket,
                  showRequester: true,
                  actions: _actionsFor(ticket),
                ),
            ],
          ),
      ],
    );
  }

  Widget? _actionsFor(SupportTicket ticket) {
    final canStart = ticket.status == SupportTicketStatus.open;
    final canResolve =
        ticket.status == SupportTicketStatus.open ||
        ticket.status == SupportTicketStatus.inProgress;
    if (!canStart && !canResolve) return null;
    return Wrap(
      spacing: 8,
      children: [
        if (canStart)
          OutlinedButton(
            onPressed: () => _update(ticket, SupportTicketStatus.inProgress),
            child: const Text('Mark in progress'),
          ),
        if (canResolve)
          FilledButton.tonal(
            onPressed: () => _update(ticket, SupportTicketStatus.resolved),
            child: const Text('Resolve'),
          ),
      ],
    );
  }
}

class _UpdateTicketSheet extends StatefulWidget {
  const _UpdateTicketSheet({
    required this.repository,
    required this.ticket,
    required this.status,
  });

  final SupportRepository repository;
  final SupportTicket ticket;
  final SupportTicketStatus status;

  @override
  State<_UpdateTicketSheet> createState() => _UpdateTicketSheetState();
}

class _UpdateTicketSheetState extends State<_UpdateTicketSheet> {
  final _note = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateTicket(
        widget.ticket.id,
        status: widget.status,
        note: _note.text,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is SettingsApiException
            ? error.message
            : 'The request could not be updated. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolving = widget.status == SupportTicketStatus.resolved;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              resolving ? 'Resolve request' : 'Mark in progress',
              style: TextStyle(
                color: palette.ink,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.ticket.subject,
              style: TextStyle(color: palette.inkSecondary, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: resolving ? 'Reply (optional)' : 'Note (optional)',
                hintText: resolving
                    ? 'What was done — the requester will see this.'
                    : 'Let them know you’re on it.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              InlineMessage(message: _error!),
            ],
            const SizedBox(height: 14),
            SettingsPrimaryButton(
              label: resolving ? 'Resolve' : 'Mark in progress',
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
