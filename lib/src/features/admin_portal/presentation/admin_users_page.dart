import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/students/student_year.dart';
import '../data/admin_student_repository.dart';
import 'student_account_import_page.dart';
import 'shop_counter_sheet.dart';
import '../../vendor_management/data/vendor_repository.dart'
    show grantsShopCounterWork, suggestedShopRole;
import '../../../core/utils/user_facing_error.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.repository,
    this.currentUserEmail,
    this.canDelete = false,
  });

  final AdminStudentRepository repository;

  /// Whether the signed-in user holds `authorization.users.delete`; gates
  /// select mode and every delete action.
  final bool canDelete;

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

  /// Select mode for bulk delete; ids of the users ticked.
  bool _selecting = false;
  final Set<String> _selectedIds = {};

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
      return;
    }
    // A shop role is only half the setup: without a counter the person's
    // queue is empty and every scan is refused.
    if (mounted && _grantsCounterWork(saved)) {
      await _chooseCounters(user.id, user.name, saved);
    }
  }

  /// Permission keys the roles [roleIds] grant together.
  List<String> _permissionKeysOf(Iterable<String> roleIds) => [
    for (final role in _roles)
      if (roleIds.contains(role.id)) ...role.permissionKeys,
  ];

  bool _grantsCounterWork(Iterable<String> roleIds) =>
      grantsShopCounterWork(_permissionKeysOf(roleIds));

  Future<void> _chooseCounters(
    String userId,
    String userName,
    Iterable<String> roleIds,
  ) async {
    final saved = await showShopCounterSheet(
      context,
      repository: widget.repository,
      userId: userId,
      userName: userName,
      defaultRole: suggestedShopRole(_permissionKeysOf(roleIds)),
    );
    if (saved == true && mounted) {
      _showMessage('$userName\'s counters were saved.');
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

  static bool _isStudent(ManagedTenantUser user) =>
      user.roles.any((role) => role.key == 'student');

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

  Future<void> _assignYear(ManagedTenantUser user) async {
    final year = await showDialog<int>(
      context: context,
      builder: (context) => _YearPickerDialog(
        title: user.yearOfStudy == null ? 'Assign year' : 'Change year',
        message: 'Choose the year of study for ${user.name}.',
        initialYear: user.yearOfStudy,
      ),
    );
    if (year == null || !mounted) return;
    try {
      await widget.repository.setUserYear(user.id, year);
      await _load();
      if (mounted) {
        _showMessage('${user.name} is now in ${studentYearLabel(year)}.');
      }
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
    }
  }

  /// Gives every student in the "Year not set" group the same year.
  Future<void> _assignYearToAll(List<ManagedTenantUser> students) async {
    if (students.isEmpty) return;
    final year = await showDialog<int>(
      context: context,
      builder: (context) => _YearPickerDialog(
        title: 'Assign year to ${students.length} '
            '${students.length == 1 ? 'student' : 'students'}',
        message: 'Every student listed under "Year not set" gets this year. '
            'You can change one student later from their profile.',
      ),
    );
    if (year == null || !mounted) return;
    var failed = 0;
    for (final student in students) {
      try {
        await widget.repository.setUserYear(student.id, year);
      } catch (_) {
        failed++;
      }
    }
    await _load();
    if (!mounted) return;
    final saved = students.length - failed;
    _showMessage(
      failed == 0
          ? '$saved ${saved == 1 ? 'student was' : 'students were'} moved to '
                '${studentYearLabel(year)}.'
          : '$saved saved, $failed could not be updated. Try those again.',
      error: failed > 0,
    );
  }

  void _showUserProfile(ManagedTenantUser user) {
    final isSelf = _isSelf(user);
    void close(BuildContext sheetContext, VoidCallback then) {
      Navigator.pop(sheetContext);
      then();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _UserProfileSheet(
        user: user,
        onEditUser: () => close(sheetContext, () => _editUser(user)),
        onEditRoles: () => close(sheetContext, () => _editRoles(user)),
        onEditCounters: _grantsCounterWork(user.roles.map((r) => r.id))
            ? () => close(
                sheetContext,
                () => _chooseCounters(
                  user.id,
                  user.name,
                  user.roles.map((r) => r.id),
                ),
              )
            : null,
        onChangePassword: () =>
            close(sheetContext, () => _changePassword(user)),
        onAssignYear: _isStudent(user)
            ? () => close(sheetContext, () => _assignYear(user))
            : null,
        onSetActive: isSelf
            ? null
            : (active) => close(sheetContext, () => _setActive(user, active)),
        onDelete: isSelf || !widget.canDelete
            ? null
            : () => close(sheetContext, () => _deleteUsers([user])),
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
        yearOfStudy: request.yearOfStudy,
      );
      await _load();
      if (mounted) _showMessage('${request.name}\'s account was created.');
    } catch (error) {
      if (mounted) _showMessage(userFacingError(error), error: true);
      return;
    }
    if (!mounted || !_grantsCounterWork(request.roleIds)) return;
    final email = request.email.trim().toLowerCase();
    final created = _users
        ?.where((user) => user.email.trim().toLowerCase() == email)
        .firstOrNull;
    await _chooseCounters(
      created?.id ?? email,
      request.name,
      request.roleIds,
    );
  }

  void _toggleSelected(ManagedTenantUser user) {
    if (_isSelf(user)) return;
    setState(() {
      if (!_selectedIds.remove(user.id)) _selectedIds.add(user.id);
    });
  }

  void _endSelection() => setState(() {
    _selecting = false;
    _selectedIds.clear();
  });

  /// Asks once, naming how many accounts go and that it cannot be undone.
  Future<bool> _confirmDelete(List<ManagedTenantUser> users) async {
    final single = users.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          single
              ? 'Delete ${users.first.name}?'
              : 'Delete ${users.length} users?',
        ),
        content: Text(
          '${single ? 'This account is' : 'These accounts are'} deleted '
          'permanently. ${single ? 'They are' : 'Everyone selected is'} '
          'signed out everywhere and can never sign in again, and the email '
          'address is freed. Payments, orders, attendance and other history '
          'they left stay on record. This cannot be undone.',
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
            child: Text(single ? 'Delete user' : 'Delete ${users.length} users'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteUsers(List<ManagedTenantUser> users) async {
    final targets = users.where((user) => !_isSelf(user)).toList();
    if (targets.isEmpty || !await _confirmDelete(targets) || !mounted) return;
    try {
      final result = await widget.repository.deleteUsers(
        targets.map((user) => user.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _selectedIds.clear();
      });
      await _load();
      if (!mounted) return;
      final deleted = result.deleted.length;
      final failed = result.failed.length;
      _showMessage(
        failed == 0
            ? (deleted == 1
                  ? '${targets.first.name} was deleted.'
                  : '$deleted users were deleted.')
            : '$deleted deleted. $failed could not be deleted: '
                  '${result.failed.values.toSet().join('; ')}',
        error: failed > 0,
      );
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
    final studentUsers = users.where(_isStudent).toList();
    final otherUsers = users.where((user) => !_isStudent(user)).toList();
    Widget card(ManagedTenantUser user) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _UserCard(
        user: user,
        selecting: _selecting,
        selected: _selectedIds.contains(user.id),
        onOpenProfile: _selecting
            ? () => _toggleSelected(user)
            : () => _showUserProfile(user),
        onDelete: _isSelf(user) || !widget.canDelete
            ? null
            : () => _deleteUsers([user]),
        onEditUser: () => _editUser(user),
        onEditRoles: () => _editRoles(user),
        onChangePassword: () => _changePassword(user),
        onAssignYear: _isStudent(user) && user.yearOfStudy == null
            ? () => _assignYear(user)
            : null,
        onAssignRole: user.roles.isEmpty ? () => _editRoles(user) : null,
        onSetActive: _isSelf(user)
            ? null
            : (active) => _setActive(user, active),
      ),
    );
    final studentGroups = groupStudentsByYearAndDepartment(
      studentUsers,
      yearOf: (user) => user.yearOfStudy,
      departmentOf: (user) => user.department ?? '',
    );

    final selectableVisible = users.where((user) => !_isSelf(user)).toList();
    final allVisibleSelected =
        selectableVisible.isNotEmpty &&
        selectableVisible.every((user) => _selectedIds.contains(user.id));
    final selectedUsers = allUsers
        .where((user) => _selectedIds.contains(user.id))
        .toList();

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              centerTitle: false,
              leading: IconButton(
                tooltip: 'Done',
                icon: const Icon(Icons.close_rounded),
                onPressed: _endSelection,
              ),
              title: Text(
                _selectedIds.isEmpty
                    ? 'Select users'
                    : '${_selectedIds.length} selected',
              ),
              actions: [
                TextButton(
                  onPressed: selectableVisible.isEmpty
                      ? null
                      : () => setState(() {
                          if (allVisibleSelected) {
                            _selectedIds.removeAll(
                              selectableVisible.map((user) => user.id),
                            );
                          } else {
                            _selectedIds.addAll(
                              selectableVisible.map((user) => user.id),
                            );
                          }
                        }),
                  child: Text(
                    allVisibleSelected ? 'Deselect all' : 'Select all',
                  ),
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: selectedUsers.isEmpty
                        ? null
                        : context.palette.danger,
                  ),
                  onPressed: selectedUsers.isEmpty
                      ? null
                      : () => _deleteUsers(selectedUsers),
                ),
              ],
            )
          : AppBar(
        centerTitle: false,
        title: const Text('User management'),
        actions: [
          if (widget.canDelete && _users != null)
            TextButton(
              onPressed: () => setState(() => _selecting = true),
              child: const Text('Select'),
            ),
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
      floatingActionButton: _selecting || _users == null || _roles.isEmpty
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
                              actionLabel:
                                  group.year == null ? 'Assign year' : null,
                              onAction: group.year == null
                                  ? () => _assignYearToAll(group.students)
                                  : null,
                            ),
                            if (group.year == null)
                              const _NoticeBanner(
                                message:
                                    'Year of study is required for every '
                                    'student. Assign one here or from a '
                                    "student's profile.",
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
                              for (final user in deptGroup.students) card(user),
                            ],
                          ],
                          if (otherUsers.isNotEmpty) ...[
                            _UserSectionHeader(
                              label: 'Staff and other users',
                              count: otherUsers.length,
                            ),
                            for (final user in otherUsers) card(user),
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
  const _UserSectionHeader({
    required this.label,
    required this.count,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final int count;
  final String? actionLabel;
  final VoidCallback? onAction;

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
        const SizedBox(width: 8),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.palette.inkSecondary,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.event_available_rounded, size: 18),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.brandInk,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  );
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
          child: Text(
            message,
            style: TextStyle(fontSize: 12.5, color: context.palette.ink),
          ),
        ),
      ],
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    this.selecting = false,
    this.selected = false,
    this.onDelete,
    required this.onOpenProfile,
    required this.onEditUser,
    required this.onEditRoles,
    required this.onChangePassword,
    this.onAssignYear,
    this.onAssignRole,
    this.onSetActive,
  });

  final ManagedTenantUser user;
  final VoidCallback onOpenProfile;
  final VoidCallback onEditUser;
  final VoidCallback onEditRoles;
  final VoidCallback onChangePassword;

  /// Shown as an inline "Assign year" action for a student with no year.
  final VoidCallback? onAssignYear;

  /// Shown as an inline "Assign role" action for a user with no role.
  final VoidCallback? onAssignRole;

  /// Deactivate (false) or reactivate (true); null hides the action, as on
  /// the administrator's own account.
  final ValueChanged<bool>? onSetActive;

  /// In select mode a tap toggles [selected] and the menu is hidden.
  final bool selecting;
  final bool selected;

  /// Null hides "Delete user" (own account, or no delete permission).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quickActions = [
      if (onAssignYear != null)
        _InlineAction(
          icon: Icons.event_available_rounded,
          label: 'Assign year',
          onTap: onAssignYear!,
        ),
      if (onAssignRole != null)
        _InlineAction(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Assign role',
          onTap: onAssignRole!,
        ),
    ];
    final card = Card(
      elevation: 0,
      color: selecting && selected ? context.palette.brandSoft : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selecting && selected
              ? context.palette.brandInk
              : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenProfile,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Checkbox(
                    value: selected,
                    // The signed-in administrator cannot delete themselves.
                    onChanged: onDelete == null ? null : (_) => onOpenProfile(),
                  ),
                ),
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
                    if (quickActions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: quickActions),
                    ],
                  ],
                ),
              ),
              if (!selecting)
              PopupMenuButton<String>(
                tooltip: 'Manage ${user.name}',
                onSelected: (value) {
                  if (value == 'profile') onOpenProfile();
                  if (value == 'edit') onEditUser();
                  if (value == 'roles') onEditRoles();
                  if (value == 'password') onChangePassword();
                  if (value == 'deactivate') onSetActive?.call(false);
                  if (value == 'reactivate') onSetActive?.call(true);
                  if (value == 'delete') onDelete?.call();
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
                  if (onDelete != null) ...[
                    if (onSetActive == null) const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: context.palette.danger,
                        ),
                        title: Text(
                          'Delete user',
                          style: TextStyle(color: context.palette.danger),
                        ),
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

/// A user's profile as an inset grouped list: identity up top, then the
/// account facts, roles, and actions, with the destructive action alone at
/// the bottom.
class _UserProfileSheet extends StatelessWidget {
  const _UserProfileSheet({
    required this.user,
    required this.onEditUser,
    required this.onEditRoles,
    required this.onChangePassword,
    this.onAssignYear,
    this.onSetActive,
    this.onEditCounters,
    this.onDelete,
  });

  final ManagedTenantUser user;
  final VoidCallback onEditUser;
  final VoidCallback onEditRoles;

  /// Present when the person's roles put them behind a shop counter.
  final VoidCallback? onEditCounters;
  final VoidCallback onChangePassword;

  /// Null for accounts that are not students.
  final VoidCallback? onAssignYear;

  /// Null on the administrator's own account.
  final ValueChanged<bool>? onSetActive;

  /// Null on the administrator's own account or without delete permission.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final year = user.yearOfStudy;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: palette.borderStrong,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: palette.brandSoft,
              child: Text(
                _initials(user.name),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: palette.brandInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: palette.inkSecondary),
          ),
          const SizedBox(height: 10),
          Center(
            child: _StatusPill(
              label: user.active ? 'Active' : 'Inactive',
              color: user.active ? palette.success : palette.danger,
              background: user.active ? palette.successSoft : palette.dangerSoft,
            ),
          ),
          const SizedBox(height: 22),
          const _GroupLabel('Account'),
          _Group(
            children: [
              _GroupRow(
                icon: Icons.person_outline_rounded,
                title: 'Name',
                value: user.name,
              ),
              _GroupRow(
                icon: Icons.mail_outline_rounded,
                title: 'Email',
                value: user.email,
              ),
              if (onAssignYear != null)
                _GroupRow(
                  icon: Icons.school_outlined,
                  title: 'Year of study',
                  value: year == null ? 'Not set' : studentYearLabel(year),
                  valueColor: year == null ? palette.danger : null,
                  onTap: onAssignYear,
                ),
              if (user.department?.trim().isNotEmpty ?? false)
                _GroupRow(
                  icon: Icons.apartment_outlined,
                  title: 'Department',
                  value: user.department!.trim(),
                ),
              _GroupRow(
                icon: Icons.fingerprint_rounded,
                title: 'User ID',
                value: user.id,
                monospace: true,
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy user ID',
                  color: palette.inkTertiary,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID copied.')),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _GroupLabel('Roles'),
          _Group(
            children: [
              if (user.roles.isEmpty)
                _GroupRow(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'No role assigned',
                  titleColor: palette.danger,
                  actionLabel: 'Assign role',
                  onTap: onEditRoles,
                )
              else ...[
                for (final role in user.roles)
                  _GroupRow(
                    icon: Icons.verified_user_outlined,
                    title: role.name,
                  ),
                _GroupRow(
                  icon: Icons.tune_rounded,
                  title: 'Edit roles',
                  titleColor: palette.brandInk,
                  onTap: onEditRoles,
                ),
                if (onEditCounters != null)
                  _GroupRow(
                    icon: Icons.storefront_outlined,
                    title: 'Shop counters',
                    titleColor: palette.brandInk,
                    onTap: onEditCounters,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          const _GroupLabel('Manage'),
          _Group(
            children: [
              _GroupRow(
                icon: Icons.edit_outlined,
                title: 'Edit name and email',
                onTap: onEditUser,
              ),
              if (onAssignYear != null)
                _GroupRow(
                  icon: Icons.event_available_rounded,
                  title: year == null ? 'Assign year' : 'Change year',
                  onTap: onAssignYear,
                ),
              _GroupRow(
                icon: Icons.lock_reset_rounded,
                title: 'Change password',
                onTap: onChangePassword,
              ),
            ],
          ),
          if (onSetActive != null) ...[
            const SizedBox(height: 22),
            _Group(
              children: [
                _GroupRow(
                  icon: user.active
                      ? Icons.person_off_outlined
                      : Icons.person_add_alt_outlined,
                  title: user.active ? 'Deactivate user' : 'Reactivate user',
                  titleColor: user.active ? palette.danger : palette.brandInk,
                  iconColor: user.active ? palette.danger : palette.brandInk,
                  showChevron: false,
                  onTap: () => onSetActive!(!user.active),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                user.active
                    ? 'Signs ${user.name} out on every device until you '
                          'reactivate the account.'
                    : '${user.name} can sign in again with their existing '
                          'password.',
                style: TextStyle(fontSize: 12, color: palette.inkSecondary),
              ),
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(height: 22),
            _Group(
              children: [
                _GroupRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete user',
                  titleColor: palette.danger,
                  iconColor: palette.danger,
                  showChevron: false,
                  onTap: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Removes the account for good. History such as payments '
                'and attendance is kept.',
                style: TextStyle(fontSize: 12, color: palette.inkSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
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

/// An inset grouped section: rows on one rounded surface, separated by
/// hairlines that start after the icon column.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 0.5, indent: 52, color: palette.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.icon,
    required this.title,
    this.value,
    this.valueColor,
    this.titleColor,
    this.iconColor,
    this.actionLabel,
    this.trailing,
    this.monospace = false,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Color? valueColor;
  final Color? titleColor;
  final Color? iconColor;
  final String? actionLabel;
  final Widget? trailing;
  final bool monospace;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 6, trailing == null ? 12 : 4, 6),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? palette.inkSecondary),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? palette.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: value == null
                    ? const SizedBox.shrink()
                    : Text(
                        value!,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: monospace ? 12 : 15,
                          fontFamily: monospace ? 'monospace' : null,
                          color: valueColor ?? palette.inkSecondary,
                        ),
                      ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.brandInk,
                  ),
                ),
              ],
              ?trailing,
              if (trailing == null && onTap != null && showChevron) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.inkTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.brandSoft,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: palette.brandInk),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.brandInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks a year of study, 1–6. Pops the chosen year, or null on cancel.
class _YearPickerDialog extends StatefulWidget {
  const _YearPickerDialog({
    required this.title,
    required this.message,
    this.initialYear,
  });

  final String title;
  final String message;
  final int? initialYear;

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int? _year = widget.initialYear;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          _YearChoices(
            selected: _year,
            onSelected: (year) => setState(() => _year = year),
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
        onPressed: _year == null ? null : () => Navigator.pop(context, _year),
        child: const Text('Save year'),
      ),
    ],
  );
}

class _YearChoices extends StatelessWidget {
  const _YearChoices({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var year = 1; year <= 6; year++)
        ChoiceChip(
          label: Text('Year $year'),
          selected: selected == year,
          onSelected: (_) => onSelected(year),
        ),
    ],
  );
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
  int? _year;
  String? _error;

  /// A student account needs a year of study; the server refuses one
  /// without it.
  bool get _createsStudent => widget.roles.any(
    (role) => _selected.contains(role.id) && role.key == 'student',
  );

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
    } else if (_createsStudent && _year == null) {
      setState(() => _error = "Choose the student's year of study.");
    } else {
      Navigator.pop(
        context,
        _CreateUserValue(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          roleIds: _selected,
          yearOfStudy: _createsStudent ? _year : null,
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
            if (_createsStudent) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Year of study (required)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _YearChoices(
                  selected: _year,
                  onSelected: (year) => setState(() => _year = year),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
    this.yearOfStudy,
  });

  final String name;
  final String email;
  final String password;
  final Set<String> roleIds;
  final int? yearOfStudy;
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
