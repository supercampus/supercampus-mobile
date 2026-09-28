import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/students/student_year.dart';
import '../data/admin_student_repository.dart';
import 'student_account_import_page.dart';
import '../../../core/utils/user_facing_error.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.repository,
    this.currentUserEmail,
  });

  final AdminStudentRepository repository;

  /// The signed-in administrator, who is never offered "Deactivate" on their
  /// own account (the server refuses it as well).
  final String? currentUserEmail;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<ManagedTenantUser>? _users;
  List<ManagedUserRole> _roles = const [];
  String _query = '';
  String? _error;
  ManagedUserRole? _selectedRoleFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final values = await Future.wait([
        widget.repository.listUsers(),
        widget.repository.listRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = values[0] as List<ManagedTenantUser>;
        _roles = values[1] as List<ManagedUserRole>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _editRoles(ManagedTenantUser user) async {
    final selected = user.roles.map((role) => role.id).toSet();
    final saved = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _RoleDialog(
        userName: user.name,
        roles: _roles,
        initialSelection: selected,
      ),
    );
    if (saved == null || !mounted) return;
    try {
      await widget.repository.setUserRoles(user.id, saved.toList());
      await _load();
      if (mounted) _showMessage('${user.name}\'s roles were updated.');
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
    }
  }

  Future<void> _changePassword(ManagedTenantUser user) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _PasswordDialog(userName: user.name),
    );
    if (password == null || !mounted) return;
    try {
      await widget.repository.setUserPassword(user.id, password);
      if (mounted) {
        _showMessage(
          'Password changed. ${user.name} was signed out from existing devices.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
    }
  }

  Future<void> _editUser(ManagedTenantUser user) async {
    final updated = await showDialog<_EditUserValue>(
      context: context,
      builder: (context) => _EditUserDialog(user: user),
    );
    if (updated == null || !mounted) return;
    try {
      await widget.repository.updateUser(
        user.id,
        name: updated.name,
        email: updated.email,
      );
      await _load();
      if (mounted) {
        _showMessage('${updated.name}\'s profile was updated.');
      }
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
    }
  }

  bool _isSelf(ManagedTenantUser user) {
    final me = widget.currentUserEmail?.trim().toLowerCase();
    return me != null && me.isNotEmpty && user.email.trim().toLowerCase() == me;
  }

  Future<void> _setActive(ManagedTenantUser user, bool active) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Reactivate user?' : 'Deactivate user?'),
        content: Text(
          active
              ? '${user.name} will be able to sign in again with their '
                    'existing password.'
              : '${user.name} will be signed out on every device and '
                    "won't be able to sign in until you reactivate the "
                    'account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: active
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(
                      dialogContext,
                    ).colorScheme.onError,
                  ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(active ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.setUserActive(user.id, active: active);
      await _load();
      if (mounted) {
        _showMessage(
          active
              ? '${user.name} was reactivated.'
              : '${user.name} was deactivated and signed out.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
    }
  }

  void _showUserProfile(ManagedTenantUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _UserProfileSheet(
        user: user,
        onEditUser: () {
          Navigator.pop(sheetContext);
          _editUser(user);
        },
        onEditRoles: () {
          Navigator.pop(sheetContext);
          _editRoles(user);
        },
        onChangePassword: () {
          Navigator.pop(sheetContext);
          _changePassword(user);
        },
      ),
    );
  }

  Future<void> _createUser() async {
    final request = await showDialog<_CreateUserValue>(
      context: context,
      builder: (context) => _CreateUserDialog(roles: _roles),
    );
    if (request == null || !mounted) return;
    try {
      await widget.repository.createUser(
        name: request.name,
        email: request.email,
        password: request.password,
        roleIds: request.roleIds.toList(),
      );
      await _load();
      if (mounted) _showMessage('${request.name}\'s account was created.');
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final allUsers = _users ?? const <ManagedTenantUser>[];
    final users = allUsers.where((user) {
      if (_selectedRoleFilter != null &&
          !user.roles.any((r) => r.id == _selectedRoleFilter!.id)) {
        return false;
      }
      final roles = user.roles.map((role) => role.name).join(' ');
      return query.isEmpty ||
          '${user.name} ${user.email} $roles'.toLowerCase().contains(query);
    }).toList();
    final studentUsers = users
        .where((user) => user.roles.any((role) => role.key == 'student'))
        .toList();
    final otherUsers = users
        .where((user) => !user.roles.any((role) => role.key == 'student'))
        .toList();
    final studentGroups = groupStudentsByYearAndDepartment(
      studentUsers,
      yearOf: (user) => user.yearOfStudy,
      departmentOf: (user) => user.department ?? '',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('User management'),
        actions: [
          IconButton(
            tooltip: 'Bulk upload students',
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      StudentAccountImportPage(repository: widget.repository),
                ),
              );
              await _load();
            },
          ),
        ],
      ),
      floatingActionButton: _users == null || _roles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _createUser,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add user'),
            ),
      body: _error != null
          ? _LoadError(onRetry: _load)
          : _users == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEC accounts',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_users!.length} users · ${_roles.length} dynamic roles',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: const InputDecoration(
                              hintText: 'Search name, email or role',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                          if (_roles.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  FilterChip(
                                    label: Text('All (${allUsers.length})'),
                                    selected: _selectedRoleFilter == null,
                                    onSelected: (_) => setState(
                                      () => _selectedRoleFilter = null,
                                    ),
                                  ),
                                  for (final role in _roles) ...[
                                    const SizedBox(width: 8),
                                    FilterChip(
                                      label: Text(
                                        '${role.name} (${allUsers.where((u) => u.roles.any((r) => r.id == role.id)).length})',
                                      ),
                                      selected:
                                          _selectedRoleFilter?.id == role.id,
                                      onSelected: (selected) => setState(
                                        () => _selectedRoleFilter =
                                            selected ? role : null,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (users.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No matching users')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          for (final group in studentGroups) ...[
                            _UserSectionHeader(
                              label: group.label,
                              count: group.students.length,
                            ),
                            for (final deptGroup in group.departments) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.apartment_outlined,
                                      size: 14,
                                      color: context.palette.inkSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      deptGroup.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: context.palette.inkSecondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${deptGroup.students.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.palette.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final user in deptGroup.students)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _UserCard(
                                    user: user,
                                    onOpenProfile: () => _showUserProfile(user),
                                    onEditUser: () => _editUser(user),
                                    onEditRoles: () => _editRoles(user),
                                    onChangePassword: () => _changePassword(user),
                                    onSetActive: _isSelf(user)
                                        ? null
                                        : (active) => _setActive(user, active),
                                  ),
                                ),
                            ],
                          ],
                          if (otherUsers.isNotEmpty) ...[
                            _UserSectionHeader(
                              label: 'Staff and other users',
                              count: otherUsers.length,
                            ),
                            for (final user in otherUsers)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _UserCard(
                                  user: user,
                                  onOpenProfile: () => _showUserProfile(user),
                                  onEditUser: () => _editUser(user),
                                  onEditRoles: () => _editRoles(user),
                                  onChangePassword: () => _changePassword(user),
                                  onSetActive: _isSelf(user)
                                      ? null
                                      : (active) => _setActive(user, active),
                                ),
                              ),
                          ],
                        ]),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _UserSectionHeader extends StatelessWidget {
  const _UserSectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
    child: Row(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onOpenProfile,
    required this.onEditUser,
    required this.onEditRoles,
    required this.onChangePassword,
    this.onSetActive,
  });

  final ManagedTenantUser user;
  final VoidCallback onOpenProfile;
  final VoidCallback onEditUser;
  final VoidCallback onEditRoles;
  final VoidCallback onChangePassword;

  /// Deactivate (false) or reactivate (true); null hides the action, as on
  /// the administrator's own account.
  final ValueChanged<bool>? onSetActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final card = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenProfile,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Text(_initials(user.name)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (!user.active) const _InactiveChip(),
                        if (user.roles.isEmpty)
                          const _RoleChip(label: 'No role assigned')
                        else
                          for (final role in user.roles)
                            _RoleChip(label: role.name),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Manage ${user.name}',
                onSelected: (value) {
                  if (value == 'profile') onOpenProfile();
                  if (value == 'edit') onEditUser();
                  if (value == 'roles') onEditRoles();
                  if (value == 'password') onChangePassword();
                  if (value == 'deactivate') onSetActive?.call(false);
                  if (value == 'reactivate') onSetActive?.call(true);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.badge_outlined),
                      title: Text('View profile'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit user'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'roles',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.admin_panel_settings_outlined),
                      title: Text('Edit roles'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.password_rounded),
                      title: Text('Change password'),
                    ),
                  ),
                  if (onSetActive != null) ...[
                    const PopupMenuDivider(),
                    if (user.active)
                      PopupMenuItem(
                        value: 'deactivate',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.person_off_outlined,
                            color: context.palette.danger,
                          ),
                          title: Text(
                            'Deactivate user',
                            style: TextStyle(color: context.palette.danger),
                          ),
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'reactivate',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.person_add_alt_outlined),
                          title: Text('Reactivate user'),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    // An inactive account reads as set aside, not gone: dimmed, still usable.
    return user.active ? card : Opacity(opacity: 0.62, child: card);
  }
}

class _InactiveChip extends StatelessWidget {
  const _InactiveChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: context.palette.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'Inactive',
      style: TextStyle(
        color: context.palette.danger,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _UserProfileSheet extends StatelessWidget {
  const _UserProfileSheet({
    required this.user,
    required this.onEditUser,
    required this.onEditRoles,
    required this.onChangePassword,
  });

  final ManagedTenantUser user;
  final VoidCallback onEditUser;
  final VoidCallback onEditRoles;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  _initials(user.name),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'User Account Details',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.fingerprint_outlined, size: 16, color: context.palette.inkSecondary),
                const SizedBox(width: 8),
                Text('User ID: ', style: TextStyle(fontSize: 12, color: context.palette.inkSecondary)),
                Expanded(
                  child: Text(
                    user.id,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  tooltip: 'Copy user ID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID copied to clipboard.')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Assigned Dynamic Roles',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.roles.isEmpty
                ? [
                    const Chip(
                      label: Text('No dynamic roles assigned'),
                      side: BorderSide.none,
                    ),
                  ]
                : [
                    for (final role in user.roles)
                      Chip(
                        avatar: const Icon(Icons.verified_user_outlined, size: 15),
                        label: Text(role.name),
                        backgroundColor: colors.primaryContainer.withValues(alpha: 0.45),
                        side: BorderSide.none,
                      ),
                  ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onEditUser,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit user profile (Name & Email)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChangePassword,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: const Text('Change password'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditRoles,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Edit roles'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: context.palette.brandInk.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: context.palette.brandInk,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({
    required this.userName,
    required this.roles,
    required this.initialSelection,
  });

  final String userName;
  final List<ManagedUserRole> roles;
  final Set<String> initialSelection;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late final Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit roles'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose at least one role for ${widget.userName}.'),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final role in widget.roles)
                    // Roles above this administrator's authority are never
                    // offered. One the user already holds stays visible but
                    // locked, so saving other changes does not drop it.
                    if (role.assignable)
                      CheckboxListTile(
                        value: _selected.contains(role.id),
                        contentPadding: EdgeInsets.zero,
                        title: Text(role.name),
                        subtitle: Text(role.key),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _selected.add(role.id);
                          } else {
                            _selected.remove(role.id);
                          }
                        }),
                      )
                    else if (widget.initialSelection.contains(role.id))
                      CheckboxListTile(
                        value: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(role.name),
                        subtitle: const Text(
                          'Managed by a platform administrator',
                        ),
                        onChanged: null,
                      ),
                ],
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
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, _selected),
        child: const Text('Save roles'),
      ),
    ],
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.userName});
  final String userName;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
    } else if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
    } else {
      Navigator.pop(context, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change password'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.userName} will be signed out from all existing devices.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              helperText: 'Minimum 8 characters',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Change password')),
    ],
  );
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user});
  final ManagedTenantUser user;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _email = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter the user\'s full name.');
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    Navigator.pop(
      context,
      _EditUserValue(name: name, email: email),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit user details'),
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
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
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
      FilledButton(
        onPressed: _submit,
        child: const Text('Save changes'),
      ),
    ],
  );
}

class _EditUserValue {
  const _EditUserValue({required this.name, required this.email});
  final String name;
  final String email;
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog({required this.roles});
  final List<ManagedUserRole> roles;

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final Set<String> _selected = {};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Enter a name and valid email address.');
    } else if (_password.text.length < 8) {
      setState(() => _error = 'The temporary password needs 8 characters.');
    } else if (_selected.isEmpty) {
      setState(() => _error = 'Choose at least one role.');
    } else {
      Navigator.pop(
        context,
        _CreateUserValue(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          roleIds: _selected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add MEC user'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Temporary password',
                helperText: 'Minimum 8 characters',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Roles',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final role in widget.roles.where((role) => role.assignable))
              CheckboxListTile(
                value: _selected.contains(role.id),
                contentPadding: EdgeInsets.zero,
                title: Text(role.name),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(role.id);
                  } else {
                    _selected.remove(role.id);
                  }
                }),
              ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create user')),
    ],
  );
}

class _CreateUserValue {
  const _CreateUserValue({
    required this.name,
    required this.email,
    required this.password,
    required this.roleIds,
  });

  final String name;
  final String email;
  final String password;
  final Set<String> roleIds;
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
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
          const Text('User accounts could not be loaded.'),
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
