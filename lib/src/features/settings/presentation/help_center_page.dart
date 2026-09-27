import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/settings_api.dart';
import '../data/support_repository.dart';
import 'ask_for_help_page.dart';
import 'external_links.dart';
import 'help_faq.dart';
import 'help_inbox_page.dart';
import 'settings_ui.dart';
import 'support_ticket_widgets.dart';

/// Whether this account holds a role that help requests are routed to (see
/// the routing table in the support API). This only decides whether the
/// inbox entry is offered — the server filters the inbox itself.
bool receivesHelpRequests(UserSession session) {
  final roles = {
    session.roleKey,
    ...session.roleIds,
  }.map((role) => role.trim().toLowerCase()).toSet();
  const handlerRoles = {
    'accountant',
    'warden',
    'hostel_warden',
    'librarian',
    'hod',
    'tenant_admin',
    'admin',
    'canteen_owner',
    'shop_owner',
    'stationery_owner',
    'laundry_owner',
  };
  return roles.any(handlerRoles.contains) ||
      session.isAccountant ||
      session.isHostelWarden ||
      session.isLibrarian ||
      session.isCanteenOwner ||
      session.isStationeryOwner ||
      session.isLaundryOwner;
}

/// Help & support: searchable FAQ, the Ask for help form, the user's own
/// requests, and SuperCampus contact links.
class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key, this.repository, this.session});

  /// Without one, only the FAQ and contact links are shown.
  final SupportRepository? repository;
  final UserSession? session;

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _search = TextEditingController();
  String _query = '';
  List<SupportTicket>? _tickets;
  String? _ticketsError;
  var _loadingTickets = false;
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final repository = widget.repository;
    if (repository == null) return;
    setState(() {
      _loadingTickets = true;
      _ticketsError = null;
    });
    try {
      final tickets = await repository.myTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loadingTickets = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingTickets = false;
        _ticketsError = error is SettingsApiException
            ? error.message
            : 'Your requests could not be loaded.';
      });
    }
  }

  Future<void> _askForHelp([String? category]) async {
    final repository = widget.repository;
    if (repository == null) return;
    final ticket = await Navigator.of(context).push<SupportTicket>(
      MaterialPageRoute(
        builder: (_) => AskForHelpPage(
          repository: repository,
          initialCategory: category,
        ),
      ),
    );
    if (ticket != null && mounted) {
      setState(() => _tickets = [ticket, ...?_tickets]);
      _loadTickets();
    }
  }

  void _openInbox() {
    final repository = widget.repository;
    if (repository == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => HelpInboxPage(repository: repository)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final repository = widget.repository;
    final session = widget.session;
    final query = _query.trim().toLowerCase();

    return SettingsPageScaffold(
      title: 'Help & support',
      children: [
        TextField(
          key: const ValueKey('faq-search'),
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          style: TextStyle(color: palette.ink),
          decoration: InputDecoration(
            hintText: 'Search help',
            prefixIcon: Icon(Icons.search_rounded, color: palette.inkSecondary),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.cancel_rounded, color: palette.inkTertiary),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
            filled: true,
            fillColor: palette.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 20),
        if (query.isEmpty && repository != null) ...[
          SettingsSection(
            footer:
                'Questions about fees, hostel, marks and other campus matters '
                'go to the office that handles them at your institution.',
            children: [
              SettingsRow(
                icon: Icons.edit_note_rounded,
                title: 'Ask for help',
                subtitle: 'Send a request to the right office',
                onTap: _askForHelp,
              ),
              if (session != null && receivesHelpRequests(session))
                SettingsRow(
                  icon: Icons.inbox_outlined,
                  title: 'Help requests inbox',
                  subtitle: 'Requests routed to you',
                  onTap: _openInbox,
                ),
            ],
          ),
          _buildMyRequests(context),
        ],
        ..._buildFaq(context, query),
        if (query.isEmpty)
          SettingsSection(
            header: 'SuperCampus',
            footer:
                'For problems with the app itself. Your institution answers '
                'questions about your account and campus services.',
            children: [
              SettingsRow(
                icon: Icons.support_agent_rounded,
                title: 'Contact SuperCampus support',
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: palette.inkTertiary,
                ),
                onTap: () => openExternalUrl(context, contactSupportUrl),
              ),
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                title: 'Email $supportEmail',
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: palette.inkTertiary,
                ),
                onTap: () =>
                    emailSupport(context, subject: 'SuperCampus app problem'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMyRequests(BuildContext context) {
    final palette = context.palette;
    final tickets = _tickets;
    final Widget body;
    if (tickets == null && _loadingTickets) {
      body = const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    } else if (_ticketsError != null && tickets == null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ticketsError!,
              style: TextStyle(color: palette.inkSecondary, fontSize: 14),
            ),
            TextButton(onPressed: _loadTickets, child: const Text('Try again')),
          ],
        ),
      );
    } else if (tickets == null || tickets.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'You haven’t sent any requests yet.',
          style: TextStyle(color: palette.inkSecondary, fontSize: 14),
        ),
      );
    } else {
      return SettingsSection(
        header: 'My requests',
        dividerIndent: 16,
        children: [
          for (final ticket in tickets) SupportTicketTile(ticket: ticket),
        ],
      );
    }
    return SettingsSection(header: 'My requests', children: [body]);
  }

  List<Widget> _buildFaq(BuildContext context, String query) {
    final palette = context.palette;
    final sections = <Widget>[];
    for (final topic in faqTopics) {
      final entries = query.isEmpty
          ? topic.entries
          : [
              for (final entry in topic.entries)
                if (entry.matches(query) ||
                    topic.title.toLowerCase().contains(query))
                  entry,
            ];
      if (entries.isEmpty) continue;
      sections.add(
        SettingsSection(
          header: topic.title,
          dividerIndent: 16,
          children: [
            for (final entry in entries)
              _FaqRow(
                entry: entry,
                expanded: query.isNotEmpty || _expanded.contains(entry.question),
                onToggle: () => setState(() {
                  if (!_expanded.remove(entry.question)) {
                    _expanded.add(entry.question);
                  }
                }),
              ),
          ],
        ),
      );
    }
    if (sections.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No answers match “${_query.trim()}”.',
                style: TextStyle(color: palette.ink, fontSize: 15),
              ),
              if (widget.repository != null)
                TextButton(
                  onPressed: _askForHelp,
                  child: const Text('Ask for help instead'),
                ),
            ],
          ),
        ),
      );
    }
    return sections;
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  final FaqEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.question,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: palette.inkTertiary,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6, right: 12),
                      child: Text(
                        entry.answer,
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
