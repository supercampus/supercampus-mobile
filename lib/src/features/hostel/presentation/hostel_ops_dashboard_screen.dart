import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

/// Staff hostel board. Every number comes from [HostelOperations], which the
/// backend computes from student residency, gate scans, approved gatepasses
/// and hostel service requests. Nothing here is estimated.
class HostelOpsDashboardScreen extends StatelessWidget {
  const HostelOpsDashboardScreen({
    super.key,
    required this.operations,
    required this.repository,
    required this.onRefresh,
  });

  final HostelOperations operations;
  final HostelRepository repository;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ops = operations;
    final queues = [
      _Queue(
        title: 'Overdue returns',
        icon: Icons.timer_off_outlined,
        tint: palette.danger,
        count: ops.overdue.length,
        open: () => _push(
          context,
          _PassListPage(
            title: 'Overdue returns',
            holders: ops.overdue,
            overdue: true,
            emptyTitle: 'No one is overdue',
            emptyMessage:
                'Residents who scanned out on a pass and are past their return time appear here.',
          ),
        ),
      ),
      for (final kind in _requestKinds)
        _Queue(
          title: kind.title,
          icon: kind.icon,
          tint: palette.brandInk,
          count: ops.requestsOf(kind.key).length,
          open: () => _push(
            context,
            _RequestQueuePage(
              kind: kind,
              initial: ops.requestsOf(kind.key),
              canUpdate: ops.canUpdate,
              repository: repository,
              onChanged: onRefresh,
            ),
          ),
        ),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            ops.scopeHostel ?? 'All hostels',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Presence is taken from gate scans.',
            style: TextStyle(color: palette.inkSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              _Metric(
                label: 'Residents',
                value: ops.residents,
                tint: palette.brandInk,
              ),
              _Metric(
                label: 'On campus',
                value: ops.inside,
                tint: palette.success,
              ),
              _Metric(
                label: 'Scanned out',
                value: ops.outside,
                tint: palette.warning,
              ),
              _Metric(
                label: 'On approved leave',
                value: ops.onLeave,
                tint: palette.info,
                onTap: () => _push(
                  context,
                  _PassListPage(
                    title: 'On approved leave',
                    holders: ops.away,
                    overdue: false,
                    emptyTitle: 'No one is on leave',
                    emptyMessage:
                        'Residents with an approved outpass or leave pass covering now appear here.',
                  ),
                ),
              ),
            ],
          ),
          if (ops.hostels.length > 1) ...[
            const SizedBox(height: 24),
            const _SectionTitle('By hostel'),
            const SizedBox(height: 8),
            _Group(
              children: [
                for (final hostel in ops.hostels)
                  _Row(
                    title: hostel.name,
                    subtitle: '${hostel.outside} scanned out',
                    trailing: Text(
                      '${hostel.residents}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Needs attention'),
          const SizedBox(height: 8),
          _Group(
            children: [
              for (final queue in queues)
                _Row(
                  leading: Icon(queue.icon, color: queue.tint, size: 22),
                  title: queue.title,
                  trailing: _CountBadge(
                    count: queue.count,
                    tint: queue.count > 0 ? queue.tint : palette.inkTertiary,
                  ),
                  onTap: queue.open,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _RequestKind {
  const _RequestKind(this.key, this.title, this.icon, this.emptyTitle);

  final String key;
  final String title;
  final IconData icon;
  final String emptyTitle;
}

const _requestKinds = [
  _RequestKind(
    'complaint',
    'Maintenance complaints',
    Icons.build_outlined,
    'No open complaints',
  ),
  _RequestKind(
    'room_change',
    'Room change requests',
    Icons.swap_horiz_rounded,
    'No room change requests',
  ),
  _RequestKind(
    'clearance',
    'Vacate clearances',
    Icons.fact_check_outlined,
    'No clearances in progress',
  ),
  _RequestKind(
    'visitor',
    'Visitor requests',
    Icons.people_alt_outlined,
    'No visitor requests waiting',
  ),
];

class _Queue {
  const _Queue({
    required this.title,
    required this.icon,
    required this.tint,
    required this.count,
    required this.open,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final int count;
  final VoidCallback open;
}

// ---------------------------------------------------------------- pass lists

class _PassListPage extends StatelessWidget {
  const _PassListPage({
    required this.title,
    required this.holders,
    required this.overdue,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String title;
  final List<HostelPassHolder> holders;
  final bool overdue;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: Text(title)),
      body: holders.isEmpty
          ? _EmptyState(title: emptyTitle, message: emptyMessage)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Group(
                  children: [
                    for (final holder in holders)
                      _Row(
                        title: holder.name,
                        subtitle: [
                          [
                            holder.rollNumber,
                            _place(holder.hostel, holder.room),
                          ].where((part) => part.isNotEmpty).join(' · '),
                          '${holder.passLabel} to ${holder.destination.isEmpty ? 'unspecified' : holder.destination}',
                          overdue
                              ? 'Due back ${_when(holder.returnAt)} · ${_late(holder.returnAt)} late'
                              : 'Back by ${_when(holder.returnAt)}${holder.exitedAt == null ? ' · not scanned out yet' : ''}',
                        ].join('\n'),
                        trailing: overdue
                            ? Icon(
                                Icons.error_outline_rounded,
                                color: palette.danger,
                              )
                            : null,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- request queue

class _RequestQueuePage extends StatefulWidget {
  const _RequestQueuePage({
    required this.kind,
    required this.initial,
    required this.canUpdate,
    required this.repository,
    required this.onChanged,
  });

  final _RequestKind kind;
  final List<HostelQueueRequest> initial;
  final bool canUpdate;
  final HostelRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_RequestQueuePage> createState() => _RequestQueuePageState();
}

class _RequestQueuePageState extends State<_RequestQueuePage> {
  late List<HostelQueueRequest> _requests = List.of(widget.initial);
  String? _busyId;

  static const _closed = {
    'resolved',
    'closed',
    'completed',
    'rejected',
    'cancelled',
  };

  List<(String, String)> _actionsFor(HostelQueueRequest request) {
    return switch ((request.kind, request.status)) {
      ('complaint', 'in_progress') => [('resolved', 'Mark resolved')],
      ('complaint', _) => [
        ('in_progress', 'Start work'),
        ('resolved', 'Mark resolved'),
      ],
      ('room_change' || 'clearance', 'approved') => [
        ('completed', 'Mark completed'),
      ],
      ('room_change' || 'clearance', _) => [
        ('approved', 'Approve'),
        ('rejected', 'Reject'),
      ],
      ('visitor', _) => [('approved', 'Approve'), ('rejected', 'Reject')],
      _ => const [],
    };
  }

  Future<void> _apply(HostelQueueRequest request, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyId = request.id);
    try {
      final updated = await widget.repository.updateRequestStatus(
        requestId: request.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _requests = [
          for (final item in _requests)
            if (item.id != request.id)
              item
            else if (!_closed.contains(updated.status))
              HostelQueueRequest(
                id: item.id,
                kind: item.kind,
                status: updated.status,
                requesterName: item.requesterName,
                rollNumber: item.rollNumber,
                hostel: item.hostel,
                room: item.room,
                createdAt: item.createdAt,
                details: updated.details,
              ),
        ];
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Marked ${updated.statusLabel.toLowerCase()}.')),
      );
      await widget.onChanged();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: Text(widget.kind.title)),
      body: _requests.isEmpty
          ? _EmptyState(
              title: widget.kind.emptyTitle,
              message: 'New requests from residents will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: _requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = _requests[index];
                final actions = widget.canUpdate
                    ? _actionsFor(request)
                    : const <(String, String)>[];
                final busy = _busyId == request.id;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.requesterName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            request.statusLabel,
                            style: TextStyle(
                              color: palette.brandInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          request.rollNumber ?? '',
                          _place(request.hostel, request.room),
                          _when(request.createdAt),
                        ].where((part) => part.isNotEmpty).join(' · '),
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (request.summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(request.summary),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (index, (status, label))
                                in actions.indexed)
                              index == 0
                                  ? FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => _apply(request, status),
                                      child: Text(label),
                                    )
                                  : OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => _apply(request, status),
                                      child: Text(label),
                                    ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------- building blocks

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.tint,
    this.onTap,
  });

  final String label;
  final int value;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _grouped(value),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: tint,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.inkSecondary,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: palette.inkTertiary,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );
}

/// An inset grouped list, iOS Settings style.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: palette.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: palette.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.tint});

  final int count;
  final Color tint;

  @override
  Widget build(BuildContext context) => Text(
    '$count',
    style: TextStyle(color: tint, fontWeight: FontWeight.w700, fontSize: 16),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 44,
              color: palette.inkTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- formatting

String _grouped(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _place(String? hostel, String? room) => [
  hostel ?? '',
  if (room != null && room.isNotEmpty) 'Room $room',
].where((part) => part.isNotEmpty).join(', ');

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _when(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '${value.day} ${_months[value.month - 1]}, $hour:$minute $period';
}

String _late(DateTime returnAt) {
  final late = DateTime.now().difference(returnAt);
  if (late.inDays >= 1) return '${late.inDays}d ${late.inHours % 24}h';
  if (late.inHours >= 1) return '${late.inHours}h ${late.inMinutes % 60}m';
  return '${late.inMinutes.clamp(0, 59)}m';
}
