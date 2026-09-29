import 'package:flutter/material.dart';

import '../data/notification_repository.dart';

class NotificationInboxSheet extends StatefulWidget {
  const NotificationInboxSheet({
    super.key,
    required this.repository,
    required this.onOpen,
    required this.onChanged,
  });

  final NotificationRepository repository;
  final ValueChanged<AppNotification> onOpen;
  final ValueChanged<NotificationInbox> onChanged;

  @override
  State<NotificationInboxSheet> createState() => _NotificationInboxSheetState();
}

class _NotificationInboxSheetState extends State<NotificationInboxSheet> {
  NotificationInbox? _inbox;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final inbox = await widget.repository.inbox();
      if (!mounted) return;
      setState(() => _inbox = inbox);
      widget.onChanged(inbox);
    } on NotificationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Notifications could not be loaded.');
      }
    }
  }

  Future<void> _markAllRead() async {
    await widget.repository.markAllRead();
    await _load();
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      await widget.repository.markRead(notification.id);
    }
    if (!mounted) return;
    if (notification.isBroadcast) {
      await showDialog<void>(
        context: context,
        builder: (context) => _BroadcastDetail(notification: notification),
      );
      if (mounted) await _load();
      return;
    }
    widget.onOpen(notification);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (inbox == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (inbox.notifications.isEmpty) {
      return const Center(child: Text('You are all caught up.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: inbox.unreadCount == 0 ? null : _markAllRead,
            child: const Text('Mark all as read'),
          ),
        ),
        for (final notification in inbox.notifications)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: notification.isRead
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.07),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => _open(notification),
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    _icon(notification.category),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: notification.imageUrl == null
                      ? Text(notification.body)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            _NotificationImage(url: notification.imageUrl!),
                          ],
                        ),
                ),
                trailing: notification.requiresAction
                    ? const Icon(Icons.chevron_right_rounded)
                    : notification.isRead
                    ? null
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationImage extends StatelessWidget {
  const _NotificationImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AspectRatio(
      aspectRatio: 2,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        semanticLabel: 'Notification image',
        errorBuilder: (_, _, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    ),
  );
}

/// A broadcast read in full: the whole message and its picture.
class _BroadcastDetail extends StatelessWidget {
  const _BroadcastDetail({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final sentBy = notification.data['sentBy']?.toString().trim() ?? '';
    return AlertDialog(
      title: Text(notification.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.imageUrl != null) ...[
              _NotificationImage(url: notification.imageUrl!),
              const SizedBox(height: 12),
            ],
            SelectableText(notification.body),
            if (sentBy.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'From $sentBy',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

IconData _icon(String category) => switch (category) {
  'broadcast' => Icons.campaign_outlined,
  'attendance' => Icons.fact_check_outlined,
  'canteen' => Icons.restaurant_outlined,
  'gatepass' => Icons.qr_code_rounded,
  'fees' => Icons.account_balance_wallet_outlined,
  'timetable' => Icons.calendar_month_outlined,
  'examination' => Icons.assignment_outlined,
  'security' => Icons.security_outlined,
  _ => Icons.notifications_outlined,
};
