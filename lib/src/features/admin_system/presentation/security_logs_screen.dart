import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_system_models.dart';
import '../data/admin_system_repository.dart';
import 'admin_system_widgets.dart';

enum _SecurityTab { sessions, activity }

/// Security Logs: login sessions (active, revoked, expired) and every
/// sign-in, failed attempt, refusal, sign-out and revocation.
class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({
    super.key,
    required this.repository,
    this.canRevoke = false,
  });

  final AdminSystemRepository repository;

  /// Whether this administrator may end someone's active session.
  final bool canRevoke;

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  static const _pageSize = 50;

  final _search = TextEditingController();
  _SecurityTab _tab = _SecurityTab.sessions;
  SessionStatus? _status;
  LoginOutcome? _outcome;
  DateTime? _from;
  DateTime? _to;

  SessionsPage? _sessionsPage;
  final List<LoginSession> _sessions = [];
  LoginEventsPage? _eventsPage;
  final List<LoginEventRecord> _events = [];
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  SecurityLogQuery get _query => SecurityLogQuery(
    status: _status,
    outcome: _outcome,
    search: _search.text,
    from: _from,
    to: _to,
  );

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_tab == _SecurityTab.sessions) {
        final page = await widget.repository.sessions(_query, limit: _pageSize);
        if (!mounted || request != _request) return;
        setState(() {
          _sessionsPage = page;
          _sessions
            ..clear()
            ..addAll(page.sessions);
        });
      } else {
        final page = await widget.repository.loginEvents(
          _query,
          limit: _pageSize,
        );
        if (!mounted || request != _request) return;
        setState(() {
          _eventsPage = page;
          _events
            ..clear()
            ..addAll(page.events);
        });
      }
      if (mounted && request == _request) setState(() => _loading = false);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      if (_tab == _SecurityTab.sessions) {
        final page = await widget.repository.sessions(
          _query,
          limit: _pageSize,
          offset: _sessions.length,
        );
        if (mounted && request == _request) {
          setState(() => _sessions.addAll(page.sessions));
        }
      } else {
        final page = await widget.repository.loginEvents(
          _query,
          limit: _pageSize,
          offset: _events.length,
        );
        if (mounted && request == _request) {
          setState(() => _events.addAll(page.events));
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickDates() async {
    final picked = await pickDayRange(context, from: _from, to: _to);
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  Future<void> _revoke(LoginSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke this session?'),
        content: Text(
          '${session.displayName} will be signed out on '
          '${session.deviceName ?? 'their device'} and must sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-revoke-session'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.revokeSession(session.id);
      if (!mounted) return;
      setState(() {
        final index = _sessions.indexWhere((item) => item.id == session.id);
        if (index >= 0) _sessions[index] = session.revoked();
      });
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${session.displayName} was signed out.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasDates = _from != null && _to != null;
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SystemPageHeader(
                  title: 'Security Logs',
                  subtitle: 'Login sessions and sign-in activity',
                  trailing: hasDates
                      ? InputChip(
                          key: const Key('security-dates'),
                          label: Text(
                            '${formatShortDay(_from!)} – ${formatShortDay(_to!)}',
                          ),
                          onPressed: _pickDates,
                          onDeleted: () {
                            setState(() {
                              _from = null;
                              _to = null;
                            });
                            _load();
                          },
                        )
                      : IconButton(
                          key: const Key('security-dates'),
                          tooltip: 'Date range',
                          onPressed: _pickDates,
                          icon: Icon(
                            Icons.calendar_today_rounded,
                            color: palette.ink,
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: SegmentedButton<_SecurityTab>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _SecurityTab.sessions,
                        label: Text('Sessions'),
                      ),
                      ButtonSegment(
                        value: _SecurityTab.activity,
                        label: Text('Sign-in activity'),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (selection) {
                      setState(() => _tab = selection.first);
                      _load();
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SystemSearchField(
                    fieldKey: const Key('security-search'),
                    controller: _search,
                    hint: 'Name, email, device or IP',
                    onSubmitted: (_) => _load(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _tab == _SecurityTab.sessions
                    ? SystemChoiceChips<SessionStatus?>(
                        selected: _status,
                        onSelected: (status) {
                          setState(() => _status = status);
                          _load();
                        },
                        options: const [
                          (null, 'All'),
                          (SessionStatus.active, 'Active'),
                          (SessionStatus.revoked, 'Ended'),
                          (SessionStatus.expired, 'Expired'),
                        ],
                      )
                    : SystemChoiceChips<LoginOutcome?>(
                        selected: _outcome,
                        onSelected: (outcome) {
                          setState(() => _outcome = outcome);
                          _load();
                        },
                        options: const [
                          (null, 'All'),
                          (LoginOutcome.success, 'Signed in'),
                          (LoginOutcome.failure, 'Failed'),
                          (LoginOutcome.blocked, 'Refused'),
                          (LoginOutcome.signedOut, 'Signed out'),
                          (LoginOutcome.revoked, 'Revoked'),
                        ],
                      ),
              ),
              if (_error == null) SliverToBoxAdapter(child: _metrics(context)),
              ..._body(context),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metrics(BuildContext context) {
    final palette = context.palette;
    final metrics = <(String, String, Color?)>[];
    if (_tab == _SecurityTab.sessions) {
      final page = _sessionsPage;
      if (page == null) return const SizedBox.shrink();
      metrics.addAll([
        ('Active', '${page.active}', palette.success),
        ('Ended', '${page.revoked}', null),
        ('Expired', '${page.expired}', null),
      ]);
    } else {
      final page = _eventsPage;
      if (page == null) return const SizedBox.shrink();
      metrics.addAll([
        ('Sign-ins', '${page.successes}', palette.success),
        (
          'Failed',
          '${page.failures}',
          page.failures > 0 ? palette.danger : null,
        ),
        ('Sign-outs', '${page.signedOut}', null),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SystemMetricRow(metrics: metrics),
    );
  }

  List<Widget> _body(BuildContext context) {
    final isSessions = _tab == _SecurityTab.sessions;
    final count = isSessions ? _sessions.length : _events.length;
    final total = isSessions
        ? _sessionsPage?.total ?? count
        : _eventsPage?.total ?? count;
    if (_loading && count == 0) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: SystemMessage(
            icon: Icons.cloud_off_rounded,
            title: "Security logs couldn't load",
            body: '$_error',
            actionLabel: 'Try again',
            onAction: _load,
          ),
        ),
      ];
    }
    if (count == 0) {
      return [
        SliverToBoxAdapter(
          child: SystemMessage(
            icon: Icons.shield_outlined,
            title: isSessions ? 'No sessions' : 'No sign-in activity',
            body: 'Nothing matches these filters.',
          ),
        ),
      ];
    }
    final palette = context.palette;
    return [
      SliverToBoxAdapter(
        child: SystemSectionLabel(isSessions ? 'Sessions' : 'Activity'),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 64,
                      color: palette.divider,
                    ),
                  if (isSessions)
                    _SessionRow(
                      session: _sessions[i],
                      onTap: () => _showSession(_sessions[i]),
                    )
                  else
                    _EventRow(
                      event: _events[i],
                      onTap: () => _showEvent(_events[i]),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      if (count < total)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator.adaptive()
                  : TextButton(
                      key: const Key('security-load-more'),
                      onPressed: _loadMore,
                      child: Text('Show more ($count of $total)'),
                    ),
            ),
          ),
        ),
    ];
  }

  void _showSession(LoginSession session) {
    final palette = context.palette;
    final canRevoke =
        widget.canRevoke &&
        session.status == SessionStatus.active &&
        !session.current;
    showSystemDetailSheet(
      context,
      title: session.displayName,
      subtitle: session.email,
      children: [
        SystemDetailLine(label: 'Status', value: _statusLabel(session)),
        SystemDetailLine(
          label: 'Signed in',
          value: formatStamp(session.signedInAt),
        ),
        SystemDetailLine(
          label: 'Last active',
          value: formatStamp(session.lastSeenAt),
        ),
        if (session.status == SessionStatus.active)
          SystemDetailLine(
            label: 'Expires',
            value: formatStamp(session.expiresAt),
          )
        else
          SystemDetailLine(label: 'Ended', value: formatStamp(session.endedAt)),
        SystemDetailLine(label: 'Ended by', value: session.endedByName),
        SystemDetailLine(label: 'Device', value: session.deviceName),
        SystemDetailLine(label: 'Device ID', value: session.deviceId),
        SystemDetailLine(
          label: 'Platform',
          value: _platformLabel(session.platform),
        ),
        SystemDetailLine(label: 'App version', value: session.appVersion),
        SystemDetailLine(label: 'IP address', value: session.ipAddress),
        SystemDetailLine(label: 'User agent', value: session.userAgent),
        SystemDetailLine(label: 'Roles', value: session.roles.join(', ')),
        SystemDetailLine(label: 'Session ID', value: session.id),
      ],
      footer: canRevoke
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('revoke-session'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.danger,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => _revoke(session),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Revoke session'),
              ),
            )
          : session.current
          ? Text(
              'This is your current session.',
              style: TextStyle(color: palette.inkSecondary),
            )
          : null,
    );
  }

  void _showEvent(LoginEventRecord event) {
    showSystemDetailSheet(
      context,
      title: event.title,
      subtitle: event.name ?? event.email,
      children: [
        SystemDetailLine(label: 'When', value: formatStamp(event.createdAt)),
        SystemDetailLine(label: 'Account', value: event.email),
        SystemDetailLine(label: 'By', value: event.actorName),
        SystemDetailLine(label: 'Device', value: event.deviceName),
        SystemDetailLine(label: 'Device ID', value: event.deviceId),
        SystemDetailLine(
          label: 'Platform',
          value: _platformLabel(event.platform),
        ),
        SystemDetailLine(label: 'App version', value: event.appVersion),
        SystemDetailLine(label: 'IP address', value: event.ipAddress),
        SystemDetailLine(label: 'User agent', value: event.userAgent),
        SystemDetailLine(label: 'Session ID', value: event.sessionId),
      ],
    );
  }
}

String _statusLabel(LoginSession session) => switch (session.status) {
  SessionStatus.active => 'Active',
  SessionStatus.expired => 'Expired',
  SessionStatus.revoked => sessionEndLabel(session.endReason),
};

String? _platformLabel(String? platform) => switch (platform) {
  null => null,
  'android' => 'Android',
  'ios' => 'iOS',
  'web' => 'Web',
  'windows' => 'Windows',
  'macos' => 'macOS',
  'linux' => 'Linux',
  final other => other,
};

IconData _deviceIcon(String? platform, String? deviceName) {
  final value = '${platform ?? ''} ${deviceName ?? ''}'.toLowerCase();
  if (value.contains('android') ||
      value.contains('ios') ||
      value.contains('iphone')) {
    return Icons.smartphone_rounded;
  }
  if (value.contains('web') || value.contains('browser')) {
    return Icons.language_rounded;
  }
  return Icons.computer_rounded;
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final LoginSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (label, color) = switch (session.status) {
      SessionStatus.active => ('Active', palette.success),
      SessionStatus.expired => ('Expired', palette.inkSecondary),
      SessionStatus.revoked => (
        session.endReason == 'revoked_by_admin'
            ? 'Revoked'
            : session.endReason == 'signed_out'
            ? 'Logged out'
            : 'Ended',
        session.endReason == 'revoked_by_admin'
            ? palette.danger
            : palette.inkSecondary,
      ),
    };
    final details = [
      session.deviceName ?? 'Unknown device',
      ?_platformLabel(session.platform),
      ?session.ipAddress,
    ].join(' · ');
    final when = session.status == SessionStatus.active
        ? 'Signed in ${formatRelative(session.signedInAt)}'
        : 'Ended ${formatRelative(session.endedAt)}';
    return InkWell(
      key: Key('session-${session.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: palette.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                _deviceIcon(session.platform, session.deviceName),
                size: 18,
                color: palette.brandInk,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          session.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                      ),
                      if (session.current) ...[
                        const SizedBox(width: 6),
                        Text(
                          'You',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.inkTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: palette.inkSecondary),
                  ),
                  Text(
                    when,
                    style: TextStyle(fontSize: 12, color: palette.inkTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SystemBadge(label: label, color: color),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});

  final LoginEventRecord event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (event.outcome) {
      LoginOutcome.success => (Icons.login_rounded, palette.success),
      LoginOutcome.failure => (Icons.error_outline_rounded, palette.danger),
      LoginOutcome.blocked => (Icons.block_rounded, palette.warning),
      LoginOutcome.signedOut => (Icons.logout_rounded, palette.inkSecondary),
      LoginOutcome.revoked => (Icons.gpp_bad_outlined, palette.danger),
    };
    final details = [
      event.name ?? event.email ?? 'Unknown account',
      ?event.deviceName,
      ?event.ipAddress,
    ].join(' · ');
    return InkWell(
      key: Key('login-event-${event.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: palette.inkSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatRelative(event.createdAt),
              style: TextStyle(fontSize: 12, color: palette.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
