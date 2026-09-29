import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/media/media_picker.dart';
import '../../../core/media/media_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../data/push_broadcast_repository.dart';

/// Picks and uploads one image, returning its URL, or null when the person
/// backs out or the upload failed (the picker reports that itself).
typedef BroadcastImagePicker = Future<String?> Function(BuildContext context);

Future<String?> _pickWithMediaScope(BuildContext context) async {
  final repository = MediaScope.maybeOf(context);
  if (repository == null) return null;
  final asset = await pickAndUploadPhoto(context, repository: repository);
  final url = asset?.secureUrl.trim();
  return url == null || url.isEmpty ? null : url;
}

const _titleMax = 120;
const _bodyMax = 2000;

/// "Push Notifications": an administrator composes a message (title, text,
/// optional image), chooses who gets it — whole roles, hand-picked people,
/// students filtered by department and year — confirms the recipient count,
/// and sends. Reach and the history of earlier broadcasts sit alongside.
///
/// Every recipient gets the message in the app's notification list. Phones
/// are reached only when the server has push delivery configured; when it
/// does not, the page says so rather than implying a push went out.
class PushBroadcastScreen extends StatefulWidget {
  const PushBroadcastScreen({
    super.key,
    required this.repository,
    this.pickImage,
  });

  final PushBroadcastRepository repository;

  /// Overrides the image picker (tests). Defaults to the app's media upload,
  /// and hides the image control where no media service is available.
  final BroadcastImagePicker? pickImage;

  @override
  State<PushBroadcastScreen> createState() => _PushBroadcastScreenState();
}

class _PushBroadcastScreenState extends State<PushBroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  BroadcastAudienceStats? _stats;
  Object? _statsError;
  List<BroadcastRecord>? _history;
  Object? _historyError;
  BroadcastDirectory? _directory;

  final Set<String> _roles = {};
  final Map<String, BroadcastRecipient> _people = {};
  String? _imageUrl;
  bool _uploading = false;
  bool _sending = false;

  PushBroadcastRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _body.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _load() async {
    await Future.wait([_loadStats(), _loadHistory()]);
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _repository.audienceStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _statsError = error);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _repository.history();
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyError = error);
    }
  }

  BroadcastImagePicker? get _imagePicker {
    if (widget.pickImage != null) return widget.pickImage;
    return MediaScope.maybeOf(context) == null ? null : _pickWithMediaScope;
  }

  Future<void> _addImage() async {
    final picker = _imagePicker;
    if (picker == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final url = await picker(context);
      if (!mounted) return;
      if (url != null) setState(() => _imageUrl = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _choosePeople() async {
    var directory = _directory;
    if (directory == null) {
      try {
        directory = await _repository.recipients();
        _directory = directory;
      } catch (error) {
        _toast(_message(error));
        return;
      }
    }
    if (!mounted) return;
    final roleNames = {
      for (final role in _stats?.roles ?? const <BroadcastRole>[])
        role.key: role.name,
    };
    final chosen = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BroadcastRecipientPicker(
          directory: directory!,
          initialSelection: _people.keys.toSet(),
          roleNames: roleNames,
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _people
        ..clear()
        ..addEntries(
          directory!.users
              .where((user) => chosen.contains(user.id))
              .map((user) => MapEntry(user.id, user)),
        );
    });
  }

  String? get _validationMessage {
    if (_title.text.trim().isEmpty) return 'Add a title.';
    if (_body.text.trim().isEmpty) return 'Add a message.';
    if (_roles.isEmpty && _people.isEmpty) {
      return 'Choose at least one role or person.';
    }
    return null;
  }

  BroadcastDraft get _draft => BroadcastDraft(
    title: _title.text,
    body: _body.text,
    imageUrl: _imageUrl,
    roles: _roles.toList()..sort(),
    userIds: _people.keys.toList(),
  );

  Future<void> _reviewAndSend() async {
    final problem = _validationMessage;
    if (problem != null) {
      _toast(problem);
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final draft = _draft;
      final reach = await _repository.preview(
        roles: draft.roles,
        userIds: draft.userIds,
      );
      if (!mounted) return;
      if (reach.recipients == 0) {
        _toast('No active account matches this audience.');
        return;
      }
      // Nothing is in flight while the person decides.
      setState(() => _sending = false);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmSendDialog(draft: draft, reach: reach),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _sending = true);
      final result = await _repository.send(draft);
      if (!mounted) return;
      final pushNote = switch (result.pushStatus) {
        'queued' =>
          ' Push queued for ${result.reach.devices} '
              'device${result.reach.devices == 1 ? '' : 's'}.',
        'no_devices' => ' No recipient has push turned on.',
        _ => ' Push was not sent: it is not configured on the server.',
      };
      _toast(
        'Sent to ${result.inAppDelivered} '
        '${result.inAppDelivered == 1 ? 'person' : 'people'} in the app.'
        '$pushNote',
      );
      setState(() {
        _title.clear();
        _body.clear();
        _imageUrl = null;
        _roles.clear();
        _people.clear();
      });
      await _load();
    } catch (error) {
      _toast(_message(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _message(Object error) => error is PushBroadcastException
      ? error.message
      : 'Something went wrong. Check your connection and try again.';

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stats = _stats;
    final canSend = stats?.canSend ?? false;
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.paddingOf(context).bottom + 32,
            ),
            children: [
              const _Header(),
              if (stats == null && _statsError == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (stats == null)
                _ErrorCard(message: _message(_statsError!), onRetry: _loadStats)
              else ...[
                if (!stats.push.configured)
                  _Notice(message: stats.push.message),
                _ReachGrid(stats: stats),
                const SizedBox(height: 24),
                if (canSend) ...[
                  const _SectionLabel('Message'),
                  _ComposeCard(
                    title: _title,
                    body: _body,
                    imageUrl: _imageUrl,
                    uploading: _uploading,
                    onAddImage: _imagePicker == null ? null : _addImage,
                    onRemoveImage: () => setState(() => _imageUrl = null),
                  ),
                  if (_title.text.trim().isNotEmpty ||
                      _body.text.trim().isNotEmpty ||
                      _imageUrl != null) ...[
                    const SizedBox(height: 12),
                    _NotificationPreview(
                      title: _title.text.trim(),
                      body: _body.text.trim(),
                      imageUrl: _imageUrl,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _SectionLabel('Audience'),
                  BroadcastAudienceBuilder(
                    roles: stats.roles,
                    selectedRoles: _roles,
                    selectedPeople: _people.values.toList(),
                    onToggleRole: (key) => setState(() {
                      if (!_roles.remove(key)) _roles.add(key);
                    }),
                    onChoosePeople: _choosePeople,
                    onRemovePerson: (id) => setState(() => _people.remove(id)),
                    onClearPeople: () => setState(_people.clear),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      key: const Key('broadcast-send'),
                      onPressed: _sending || _uploading ? null : _reviewAndSend,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_sending ? 'Sending…' : 'Review and send'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ],
              const _SectionLabel('Broadcast history'),
              _HistorySection(
                history: _history,
                error: _historyError == null ? null : _message(_historyError!),
                onRetry: _loadHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            Transform.translate(
              offset: const Offset(-8, 0),
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: palette.ink,
                ),
              ),
            ),
          Text(
            'Push Notifications',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Broadcast messages to app users',
            style: TextStyle(fontSize: 14, color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: context.palette.inkSecondary,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('push-not-configured'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined, color: palette.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message.isEmpty
                  ? 'Push delivery is not configured. Messages reach the '
                        'in-app notification list only.'
                  : message,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: context.palette.inkSecondary),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ReachGrid extends StatelessWidget {
  const _ReachGrid({required this.stats});

  final BroadcastAudienceStats stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final platforms = stats.tokensByPlatform;
    final tiles = [
      _StatTile(
        label: 'Total users',
        value: stats.totalUsers,
        icon: Icons.people_alt_outlined,
        color: palette.brand,
      ),
      _StatTile(
        label: 'Push enabled',
        value: stats.pushEnabledUsers,
        icon: Icons.notifications_active_outlined,
        color: palette.success,
      ),
      _StatTile(
        label: 'No push token',
        value: stats.noPushTokenUsers,
        icon: Icons.notifications_off_outlined,
        color: palette.warning,
      ),
      _StatTile(
        label: 'Devices',
        value: stats.totalTokens,
        icon: Icons.smartphone_outlined,
        color: palette.info,
        detail:
            'Android ${platforms.android} · iOS ${platforms.ios}'
            '${platforms.web > 0 ? ' · Web ${platforms.web}' : ''}',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.detail,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      excludeSemantics: true,
      child: _Card(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(
              NumberFormat.decimalPattern().format(value),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: palette.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.inkSecondary),
            ),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: palette.inkTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComposeCard extends StatelessWidget {
  const _ComposeCard({
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.uploading,
    required this.onAddImage,
    required this.onRemoveImage,
  });

  final TextEditingController title;
  final TextEditingController body;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onAddImage;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('broadcast-title'),
            controller: title,
            maxLength: _titleMax,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Campus closed tomorrow',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('broadcast-body'),
            controller: body,
            maxLength: _bodyMax,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 2,
                    child: Image.network(
                      imageUrl!,
                      key: const Key('broadcast-image-preview'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: palette.surfaceMuted,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: palette.inkTertiary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      key: const Key('broadcast-image-remove'),
                      tooltip: 'Remove image',
                      onPressed: onRemoveImage,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            )
          else if (onAddImage != null)
            OutlinedButton.icon(
              key: const Key('broadcast-image-add'),
              onPressed: uploading ? null : onAddImage,
              icon: uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                uploading ? 'Uploading image…' : 'Add image (optional)',
              ),
            ),
        ],
      ),
    );
  }
}

/// Roughly how the message will look in a phone's notification shade.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({
    required this.title,
    required this.body,
    required this.imageUrl,
  });

  final String title;
  final String body;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Notification preview',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_rounded, size: 16, color: palette.brand),
                const SizedBox(width: 6),
                Text(
                  'SuperCampus · now',
                  style: TextStyle(fontSize: 12, color: palette.inkSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title.isEmpty ? 'Title' : title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: title.isEmpty ? palette.inkTertiary : palette.ink,
              ),
            ),
            Text(
              body.isEmpty ? 'Message' : body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: body.isEmpty
                    ? palette.inkTertiary
                    : palette.inkSecondary,
              ),
            ),
            if (imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 2,
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Whole roles as chips (with how many hold each and how many can get a
/// push), plus hand-picked people and students.
class BroadcastAudienceBuilder extends StatelessWidget {
  const BroadcastAudienceBuilder({
    super.key,
    required this.roles,
    required this.selectedRoles,
    required this.selectedPeople,
    required this.onToggleRole,
    required this.onChoosePeople,
    required this.onRemovePerson,
    required this.onClearPeople,
  });

  final List<BroadcastRole> roles;
  final Set<String> selectedRoles;
  final List<BroadcastRecipient> selectedPeople;
  final ValueChanged<String> onToggleRole;
  final VoidCallback onChoosePeople;
  final ValueChanged<String> onRemovePerson;
  final VoidCallback onClearPeople;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visibleRoles = roles.where((role) => role.users > 0).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Roles',
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.ink),
          ),
          const SizedBox(height: 8),
          if (visibleRoles.isEmpty)
            Text(
              'No role has members yet.',
              style: TextStyle(color: palette.inkSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in visibleRoles)
                  FilterChip(
                    key: Key('broadcast-role-${role.key}'),
                    selected: selectedRoles.contains(role.key),
                    onSelected: (_) => onToggleRole(role.key),
                    label: Text('${role.name} · ${role.users}'),
                    tooltip:
                        '${role.pushEnabledUsers} of ${role.users} have push on',
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Divider(height: 1, color: palette.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'People and students',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    Text(
                      selectedPeople.isEmpty
                          ? 'Search anyone, or filter students by department and year'
                          : '${selectedPeople.length} selected',
                      key: const Key('broadcast-people-count'),
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('broadcast-choose-people'),
                onPressed: onChoosePeople,
                child: Text(selectedPeople.isEmpty ? 'Choose' : 'Edit'),
              ),
            ],
          ),
          if (selectedPeople.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final person in selectedPeople.take(12))
                  InputChip(
                    label: Text(person.name),
                    onDeleted: () => onRemovePerson(person.id),
                    deleteButtonTooltipMessage: 'Remove ${person.name}',
                  ),
                if (selectedPeople.length > 12)
                  Chip(label: Text('+${selectedPeople.length - 12} more')),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onClearPeople,
                child: const Text('Clear people'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmSendDialog extends StatelessWidget {
  const _ConfirmSendDialog({required this.draft, required this.reach});

  final BroadcastDraft draft;
  final BroadcastReach reach;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final people = reach.recipients == 1 ? 'person' : 'people';
    final devices = reach.devices == 1 ? 'device' : 'devices';
    return AlertDialog(
      title: Text('Send to ${reach.recipients} $people?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“${draft.title.trim()}”',
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.ink),
          ),
          const SizedBox(height: 12),
          _ConfirmLine(
            icon: Icons.inbox_outlined,
            text: 'In-app notification for all ${reach.recipients} $people',
          ),
          if (reach.pushConfigured)
            _ConfirmLine(
              icon: Icons.notifications_active_outlined,
              text: reach.devices == 0
                  ? 'No recipient has push turned on'
                  : 'Push to ${reach.devices} $devices '
                        '(${reach.pushRecipients} $people with push on)',
            )
          else
            _ConfirmLine(
              icon: Icons.notifications_off_outlined,
              color: palette.warning,
              text:
                  'No push will be sent: push delivery is not configured '
                  'on the server',
            ),
          if (draft.imageUrl != null)
            const _ConfirmLine(
              icon: Icons.image_outlined,
              text: 'Includes an image',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('broadcast-confirm-send'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color ?? context.palette.inkSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.history,
    required this.error,
    required this.onRetry,
  });

  final List<BroadcastRecord>? history;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = history;
    if (items == null && error != null) {
      return _ErrorCard(message: error!, onRetry: onRetry);
    }
    if (items == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return _Card(
        child: Text(
          'No broadcasts yet. Messages you send appear here with who sent '
          'them and how far they got.',
          style: TextStyle(color: palette.inkSecondary),
        ),
      );
    }
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: palette.divider),
            _HistoryTile(record: items[i]),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final BroadcastRecord record;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final when = DateFormat('d MMM y, h:mm a').format(record.createdAt);
    final pushColor = switch (record.pushStatus) {
      'not_configured' => palette.warning,
      'no_devices' => palette.inkTertiary,
      _ => record.pushFailed > 0 ? palette.danger : palette.success,
    };
    return Padding(
      key: Key('broadcast-history-${record.id}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.inkSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'To ${record.audienceSummary.isEmpty ? 'selected people' : record.audienceSummary}',
                  style: TextStyle(fontSize: 12.5, color: palette.ink),
                ),
                Text(
                  '${record.sentByName} · $when',
                  style: TextStyle(fontSize: 12.5, color: palette.inkTertiary),
                ),
                const SizedBox(height: 6),
                Text(
                  'In app: ${record.recipients} · Read: ${record.read}',
                  style: TextStyle(fontSize: 12.5, color: palette.inkSecondary),
                ),
                Text(
                  record.pushSummary,
                  style: TextStyle(fontSize: 12.5, color: pushColor),
                ),
              ],
            ),
          ),
          if (record.imageUrl != null) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                record.imageUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.square(dimension: 56),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen, searchable multi-select over everyone in the institution.
/// "Students" narrows to student accounts and offers department and year
/// filters; "Select all shown" adds every match at once.
class BroadcastRecipientPicker extends StatefulWidget {
  const BroadcastRecipientPicker({
    super.key,
    required this.directory,
    this.initialSelection = const {},
    this.roleNames = const {},
  });

  final BroadcastDirectory directory;
  final Set<String> initialSelection;
  final Map<String, String> roleNames;

  @override
  State<BroadcastRecipientPicker> createState() =>
      _BroadcastRecipientPickerState();
}

class _BroadcastRecipientPickerState extends State<BroadcastRecipientPicker> {
  late final Set<String> _selected = {...widget.initialSelection};
  final _search = TextEditingController();
  bool _studentsOnly = true;
  String? _department;
  String? _year;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    if (!widget.directory.users.any((user) => user.isStudent)) {
      _studentsOnly = false;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<BroadcastRecipient> get _matches {
    final query = _search.text.trim().toLowerCase();
    return widget.directory.users.where((user) {
      if (_studentsOnly && !user.isStudent) return false;
      if (_studentsOnly &&
          _department != null &&
          user.department != _department) {
        return false;
      }
      if (_studentsOnly && _year != null && user.year != _year) return false;
      if (query.isEmpty) return true;
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          (user.roll?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<String> _values(String? Function(BroadcastRecipient) read) {
    final values = {
      for (final user in widget.directory.users)
        if (user.isStudent && read(user) != null) read(user)!,
    }.toList()..sort();
    return values;
  }

  String _subtitle(BroadcastRecipient user) {
    final parts = <String>[
      if (user.roll != null) user.roll!,
      if (user.isStudent) ...[
        if (user.department != null) user.department!,
        if (user.year != null) 'Year ${user.year}',
      ] else
        user.roles.map((role) => widget.roleNames[role] ?? role).join(', '),
    ];
    final text = parts.where((part) => part.isNotEmpty).join(' · ');
    return text.isEmpty ? user.email : text;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final matches = _matches;
    final allShownSelected =
        matches.isNotEmpty &&
        matches.every((user) => _selected.contains(user.id));
    final departments = _values((user) => user.department);
    final years = _values((user) => user.year);
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      appBar: AppBar(
        title: const Text('Choose people'),
        actions: [
          TextButton(
            key: const Key('recipient-picker-done'),
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text('Done (${_selected.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('recipient-search'),
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search name, email or roll number',
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SegmentedButton<bool>(
                  key: const Key('recipient-scope'),
                  segments: const [
                    ButtonSegment(value: true, label: Text('Students')),
                    ButtonSegment(value: false, label: Text('Everyone')),
                  ],
                  selected: {_studentsOnly},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _studentsOnly = value.first),
                ),
                if (_studentsOnly && departments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _FilterMenu(
                    key: const Key('recipient-department'),
                    label: 'Department',
                    value: _department,
                    options: departments,
                    format: (value) => value,
                    onChanged: (value) => setState(() => _department = value),
                  ),
                ],
                if (_studentsOnly && years.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _FilterMenu(
                    key: const Key('recipient-year'),
                    label: 'Year',
                    value: _year,
                    options: years,
                    format: (value) => 'Year $value',
                    onChanged: (value) => setState(() => _year = value),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${matches.length} shown · ${_selected.length} selected',
                    key: const Key('recipient-summary'),
                    style: TextStyle(fontSize: 13, color: palette.inkSecondary),
                  ),
                ),
                TextButton(
                  key: const Key('recipient-select-all'),
                  onPressed: matches.isEmpty
                      ? null
                      : () => setState(() {
                          if (allShownSelected) {
                            _selected.removeAll(matches.map((user) => user.id));
                          } else {
                            _selected.addAll(matches.map((user) => user.id));
                          }
                        }),
                  child: Text(
                    allShownSelected ? 'Deselect shown' : 'Select all shown',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Text(
                      'No one matches.',
                      style: TextStyle(color: palette.inkSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final user = matches[index];
                      final selected = _selected.contains(user.id);
                      return CheckboxListTile(
                        key: Key('recipient-${user.id}'),
                        value: selected,
                        onChanged: (_) => setState(() {
                          if (!_selected.remove(user.id)) {
                            _selected.add(user.id);
                          }
                        }),
                        title: Text(user.name),
                        subtitle: Text(
                          _subtitle(user),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: Icon(
                          user.pushEnabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          size: 20,
                          semanticLabel: user.pushEnabled
                              ? 'Push on'
                              : 'No push token',
                          color: user.pushEnabled
                              ? palette.success
                              : palette.inkTertiary,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final String Function(String) format;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (selected) => onChanged(selected.isEmpty ? null : selected),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text('All ${label.toLowerCase()}s')),
        for (final option in options)
          PopupMenuItem(value: option, child: Text(format(option))),
      ],
      child: Chip(
        avatar: const Icon(Icons.filter_list_rounded, size: 18),
        label: Text(value == null ? label : format(value!)),
      ),
    );
  }
}
