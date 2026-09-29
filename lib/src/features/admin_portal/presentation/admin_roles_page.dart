import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_facing_error.dart';
import '../data/admin_roles_repository.dart';

/// Role management for the Admin Desk: list, create, edit (name,
/// description, permissions) and delete tenant roles. Each action is offered
/// only when the signed-in user holds its permission; the server enforces
/// the same rules.
class AdminRolesPage extends StatefulWidget {
  const AdminRolesPage({
    super.key,
    required this.repository,
    this.canCreate = false,
    this.canUpdate = false,
    this.canDelete = false,
  });

  final AdminRolesRepository repository;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;

  @override
  State<AdminRolesPage> createState() => _AdminRolesPageState();
}

class _AdminRolesPageState extends State<AdminRolesPage> {
  List<RoleDefinition>? _roles;
  List<PermissionDefinition> _permissions = const [];
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final roles = await widget.repository.listRoles();
      List<PermissionDefinition> permissions = const [];
      if (widget.canCreate || widget.canUpdate) {
        try {
          permissions = await widget.repository.listPermissions();
        } catch (_) {
          // The catalogue needs its own permission; without it the list
          // still works and the editor explains why it cannot pick.
        }
      }
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permissions = permissions;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _createRole() async {
    final value = await showDialog<_NewRoleValue>(
      context: context,
      builder: (_) => _NewRoleDialog(
        existingKeys: {for (final role in _roles ?? const []) role.key},
      ),
    );
    if (value == null || !mounted) return;
    try {
      final id = await widget.repository.createRole(
        key: value.key,
        name: value.name,
        team: value.team,
        description: value.description,
        portalFamily: value.portalFamily,
      );
      await _load();
      if (!mounted) return;
      _showMessage('${value.name} was created. Choose what it can do.');
      final created = _roles?.where((role) => role.id == id).firstOrNull;
      if (created != null) await _openRole(created);
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
    }
  }

  Future<void> _openRole(RoleDefinition role) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RoleEditorPage(
          role: role,
          roles: _roles ?? const [],
          permissions: _permissions,
          repository: widget.repository,
          canUpdate: widget.canUpdate && role.editable,
          canDelete: widget.canDelete && role.deletable,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final needle = _query.trim().toLowerCase();
    final roles = (_roles ?? const <RoleDefinition>[])
        .where(
          (role) =>
              needle.isEmpty ||
              '${role.name} ${role.key} ${role.team} ${role.description}'
                  .toLowerCase()
                  .contains(needle),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Roles')),
      floatingActionButton: widget.canCreate && _roles != null
          ? FloatingActionButton.extended(
              onPressed: _createRole,
              icon: const Icon(Icons.add_moderator_outlined),
              label: const Text('New role'),
            )
          : null,
      body: _error != null
          ? _RolesLoadError(message: _error!, onRetry: _load)
          : _roles == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Text(
                    '${_roles!.length} roles',
                    style: TextStyle(fontSize: 13, color: palette.inkSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search roles',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (roles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: Text('No matching roles')),
                    )
                  else
                    Material(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < roles.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 64,
                                color: palette.divider,
                              ),
                            _RoleRow(
                              role: roles[i],
                              onTap: () => _openRole(roles[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, required this.onTap});

  final RoleDefinition role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final details = [
      role.key,
      if (role.team.trim().isNotEmpty) role.team.trim(),
      _familyLabel(role.portalFamily),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: palette.brandSoft,
              child: Icon(
                role.protected || !role.assignable
                    ? Icons.lock_outline_rounded
                    : Icons.verified_user_outlined,
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
                          role.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: palette.ink,
                          ),
                        ),
                      ),
                      if (role.protected || role.system) ...[
                        const SizedBox(width: 8),
                        _Tag(label: role.protected ? 'Protected' : 'System'),
                      ],
                      if (!role.active) ...[
                        const SizedBox(width: 6),
                        const _Tag(label: 'Inactive'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: palette.inkSecondary),
                  ),
                  if (role.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      role.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: palette.ink),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${role.memberCount}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                Text(
                  role.memberCount == 1 ? 'member' : 'members',
                  style: TextStyle(fontSize: 11, color: palette.inkSecondary),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: palette.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: context.palette.brandInk.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: context.palette.brandInk,
      ),
    ),
  );
}

String _familyLabel(String family) => switch (family) {
  'student' => 'Student app',
  'parent' => 'Parent app',
  'admin' => 'Admin portal',
  'platform-control' => 'Platform control',
  _ => 'Staff app',
};

/// Derives a role key from a name: "Hostel Warden" -> "hostel_warden".
String roleKeyFromName(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

class _NewRoleValue {
  const _NewRoleValue({
    required this.name,
    required this.key,
    required this.team,
    required this.description,
    required this.portalFamily,
  });

  final String name;
  final String key;
  final String team;
  final String description;
  final String portalFamily;
}

class _NewRoleDialog extends StatefulWidget {
  const _NewRoleDialog({required this.existingKeys});
  final Set<String> existingKeys;

  @override
  State<_NewRoleDialog> createState() => _NewRoleDialogState();
}

class _NewRoleDialogState extends State<_NewRoleDialog> {
  final _name = TextEditingController();
  final _team = TextEditingController();
  final _description = TextEditingController();
  String _family = 'staff';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _team.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final key = roleKeyFromName(name);
    if (name.isEmpty || key.isEmpty) {
      setState(() => _error = 'Give the role a name.');
      return;
    }
    if (widget.existingKeys.contains(key)) {
      setState(() => _error = 'A role named like this already exists.');
      return;
    }
    Navigator.pop(
      context,
      _NewRoleValue(
        name: name,
        key: key,
        team: _team.text.trim(),
        description: _description.text.trim(),
        portalFamily: _family,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New role'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Role name',
                helperText: _name.text.trim().isEmpty
                    ? null
                    : 'Key: ${roleKeyFromName(_name.text)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _team,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Team (optional)',
                hintText: 'For example Hostel or Finance',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What this role is for (optional)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Signs in to', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final family in const ['staff', 'admin', 'student', 'parent'])
                  ChoiceChip(
                    label: Text(_familyLabel(family)),
                    selected: _family == family,
                    onSelected: (_) => setState(() => _family = family),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create role')),
    ],
  );
}

/// Full-screen editor for one role: details, the permission picker and,
/// at the bottom and apart from the rest, delete.
class _RoleEditorPage extends StatefulWidget {
  const _RoleEditorPage({
    required this.role,
    required this.roles,
    required this.permissions,
    required this.repository,
    required this.canUpdate,
    required this.canDelete,
  });

  final RoleDefinition role;
  final List<RoleDefinition> roles;
  final List<PermissionDefinition> permissions;
  final AdminRolesRepository repository;
  final bool canUpdate;
  final bool canDelete;

  @override
  State<_RoleEditorPage> createState() => _RoleEditorPageState();
}

class _RoleEditorPageState extends State<_RoleEditorPage> {
  late final _name = TextEditingController(text: widget.role.name);
  late final _description = TextEditingController(
    text: widget.role.description,
  );
  late final Set<String> _selected = {...widget.role.permissionKeys};
  final Set<String> _expanded = {};
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim() != widget.role.name ||
      _description.text.trim() != widget.role.description.trim() ||
      _selected.length != widget.role.permissionKeys.length ||
      !_selected.containsAll(widget.role.permissionKeys);

  bool get _permissionsChanged =>
      _selected.length != widget.role.permissionKeys.length ||
      !_selected.containsAll(widget.role.permissionKeys);

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _showMessage('The role needs a name.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (name != widget.role.name ||
          _description.text.trim() != widget.role.description.trim()) {
        await widget.repository.updateRole(
          widget.role.id,
          name: name,
          description: _description.text.trim(),
        );
      }
      if (_permissionsChanged) {
        final existingScopes = {
          ...widget.role.websitePermissions,
          ...widget.role.appPermissions,
        };
        await widget.repository.setRolePermissions(widget.role.id, {
          for (final key in _selected)
            key: existingScopes[key] ?? 'institution',
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name was saved.')));
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(userFacingError(error), error: true);
      }
    }
  }

  Future<void> _delete() async {
    final role = widget.role;
    String? reassignTo;
    if (role.memberCount > 0) {
      reassignTo = await showDialog<String>(
        context: context,
        builder: (_) => _ReassignDialog(
          role: role,
          candidates: widget.roles
              .where(
                (candidate) =>
                    candidate.id != role.id &&
                    candidate.active &&
                    candidate.assignable,
              )
              .toList(),
        ),
      );
      if (reassignTo == null || !mounted) return;
    }
    final target = widget.roles.where((r) => r.id == reassignTo).firstOrNull;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${role.name}?'),
        content: Text(
          target == null
              ? 'This role and its permissions are removed permanently.'
              : '${role.memberCount} '
                    '${role.memberCount == 1 ? 'person moves' : 'people move'} '
                    'to ${target.name}, then this role and its permissions '
                    'are removed permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete role'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteRole(role.id, reassignTo: reassignTo);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${role.name} was deleted.')));
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(userFacingError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final role = widget.role;
    final editable = widget.canUpdate && !_saving;
    final catalogue = {for (final p in widget.permissions) p.key: p};
    final groups = groupPermissions(widget.permissions, query: _query);
    // Keys the role holds that the catalogue does not list (retired or
    // reserved) stay on the role untouched.
    final unlisted = _selected
        .where((key) => !catalogue.containsKey(key))
        .toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(role.name),
        actions: [
          if (widget.canUpdate)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _dirty && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          if (!widget.canUpdate)
            _Notice(
              text: role.protected
                  ? 'This is a protected system role. It cannot be changed.'
                  : !role.assignable
                  ? 'Only a platform administrator can change this role.'
                  : 'You can view this role but not change it.',
            ),
          const _SectionLabel('Details'),
          _Surface(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    enabled: editable,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    enabled: editable,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  _FactRow(label: 'Key', value: role.key),
                  _FactRow(label: 'Team', value: role.team.isEmpty ? '—' : role.team),
                  _FactRow(
                    label: 'Signs in to',
                    value: _familyLabel(role.portalFamily),
                  ),
                  _FactRow(label: 'Members', value: '${role.memberCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _SectionLabel('Permissions · ${_selected.length} selected'),
          if (widget.permissions.isEmpty)
            const _Notice(
              text:
                  'The permission catalogue could not be loaded. You need the '
                  '"View permission catalog" permission to change what a role '
                  'can do.',
            )
          else ...[
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search permissions',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _Surface(
              child: Column(
                children: [
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No matching permissions'),
                    ),
                  for (final entry in groups.entries)
                    _PermissionGroup(
                      title: moduleLabel(entry.key),
                      permissions: entry.value,
                      selected: _selected,
                      expanded:
                          _query.trim().isNotEmpty ||
                          _expanded.contains(entry.key),
                      enabled: editable,
                      onExpand: (open) => setState(() {
                        open ? _expanded.add(entry.key) : _expanded.remove(entry.key);
                      }),
                      onToggle: (key, on) => setState(() {
                        on ? _selected.add(key) : _selected.remove(key);
                      }),
                      onToggleAll: (on) => setState(() {
                        for (final permission in entry.value) {
                          on
                              ? _selected.add(permission.key)
                              : _selected.remove(permission.key);
                        }
                      }),
                    ),
                ],
              ),
            ),
            if (unlisted.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Also keeps: ${unlisted.join(', ')}',
                  style: TextStyle(fontSize: 12, color: palette.inkSecondary),
                ),
              ),
            ],
          ],
          if (widget.canDelete) ...[
            const SizedBox(height: 28),
            _Surface(
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: palette.danger),
                title: Text(
                  'Delete role',
                  style: TextStyle(color: palette.danger, fontWeight: FontWeight.w500),
                ),
                onTap: _saving ? null : _delete,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                role.memberCount == 0
                    ? 'Nobody has this role.'
                    : 'You will choose a role for its ${role.memberCount} '
                          '${role.memberCount == 1 ? 'member' : 'members'} first.',
                style: TextStyle(fontSize: 12, color: palette.inkSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionGroup extends StatelessWidget {
  const _PermissionGroup({
    required this.title,
    required this.permissions,
    required this.selected,
    required this.expanded,
    required this.enabled,
    required this.onExpand,
    required this.onToggle,
    required this.onToggleAll,
  });

  final String title;
  final List<PermissionDefinition> permissions;
  final Set<String> selected;
  final bool expanded;
  final bool enabled;
  final ValueChanged<bool> onExpand;
  final void Function(String key, bool on) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = permissions.where((p) => selected.contains(p.key)).length;
    final all = count == permissions.length;
    return Column(
      children: [
        InkWell(
          onTap: () => onExpand(!expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
                Text(
                  '$count of ${permissions.length}',
                  style: TextStyle(fontSize: 12.5, color: palette.inkSecondary),
                ),
                if (enabled && expanded)
                  TextButton(
                    onPressed: () => onToggleAll(!all),
                    child: Text(all ? 'None' : 'All'),
                  ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: palette.inkTertiary,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final permission in permissions)
            CheckboxListTile(
              value: selected.contains(permission.key),
              dense: true,
              onChanged: enabled
                  ? (on) => onToggle(permission.key, on == true)
                  : null,
              title: Text(permission.name.isEmpty ? permission.key : permission.name),
              subtitle: Text(
                permission.description.isEmpty
                    ? permission.key
                    : '${permission.description}\n${permission.key}',
                style: TextStyle(fontSize: 11.5, color: palette.inkSecondary),
              ),
              isThreeLine: permission.description.isNotEmpty,
            ),
        Divider(height: 1, thickness: 0.5, color: palette.divider),
      ],
    );
  }
}

class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.role, required this.candidates});
  final RoleDefinition role;
  final List<RoleDefinition> candidates;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  String? _target;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Move members first'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.role.memberCount} '
            '${widget.role.memberCount == 1 ? 'person has' : 'people have'} '
            '${widget.role.name}. Choose the role they move to.',
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: RadioGroup<String>(
                groupValue: _target,
                onChanged: (value) => setState(() => _target = value),
                child: Column(
                  children: [
                    for (final candidate in widget.candidates)
                      RadioListTile<String>(
                        value: candidate.id,
                        contentPadding: EdgeInsets.zero,
                        title: Text(candidate.name),
                        subtitle: Text(candidate.key),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _target == null ? null : () => Navigator.pop(context, _target),
        child: const Text('Continue'),
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: context.palette.inkSecondary,
      ),
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: context.palette.ink)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: context.palette.inkSecondary),
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.palette.warningSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: context.palette.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: context.palette.ink)),
        ),
      ],
    ),
  );
}

class _RolesLoadError extends StatelessWidget {
  const _RolesLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
