import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authRepository,
    required this.onSignedIn,
  });

  final AuthRepository authRepository;
  final ValueChanged<UserSession> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  UserRole _selectedRole = UserRole.student;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _applyRoleDefaults(_selectedRole);
  }

  void _applyRoleDefaults(UserRole role) {
    _emailController.text = role.defaultEmail;
    _passwordController.text = 'password123';
  }

  void _onRoleChanged(UserRole role) {
    if (_selectedRole == role) return;
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
      _applyRoleDefaults(role);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final session = await widget.authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );
      if (mounted) widget.onSignedIn(session);
    } on AuthenticationException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'We could not sign you in. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _quickDemoLogin(UserRole role) async {
    setState(() {
      _selectedRole = role;
      _applyRoleDefaults(role);
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      final session = await widget.authRepository.signIn(
        email: role.defaultEmail,
        password: 'password123',
        role: role,
      );
      if (mounted) widget.onSignedIn(session);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to sign in to demo portal.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showPasswordReset() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final resetFormKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Form(
          key: resetFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your registered email and we will send you a reset link.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
                onFieldSubmitted: (_) {
                  if (resetFormKey.currentState!.validate()) {
                    Navigator.of(context).pop(controller.text.trim());
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (resetFormKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (email == null || !mounted) return;
    await widget.authRepository.sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('A reset link has been sent to $email.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: SizedBox(
                    width: 480,
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BrandHeader(selectedRole: _selectedRole),
                            const SizedBox(height: 24),
                            Text(
                              'Select Your Campus Portal',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.muted,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _RoleSelector(
                              selectedRole: _selectedRole,
                              onRoleSelected: _onRoleChanged,
                            ),
                            const SizedBox(height: 24),
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Sign in as ${_selectedRole.label}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Enter your account details or use 1-tap demo credentials.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.muted),
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Email address',
                                        prefixIcon: Icon(Icons.mail_outline),
                                      ),
                                      validator: _validateEmail,
                                      onFieldSubmitted: (_) =>
                                          _passwordFocusNode.requestFocus(),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: _validatePassword,
                                      onFieldSubmitted: (_) {
                                        if (!_isSubmitting) _submit();
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _showPasswordReset,
                                        child: const Text('Forgot password?'),
                                      ),
                                    ),
                                    if (_errorMessage != null) ...[
                                      const SizedBox(height: 6),
                                      _ErrorBanner(message: _errorMessage!),
                                      const SizedBox(height: 18),
                                    ] else
                                      const SizedBox(height: 10),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        backgroundColor: _roleColor(
                                          _selectedRole,
                                        ),
                                      ),
                                      onPressed: _isSubmitting ? null : _submit,
                                      child: _isSubmitting
                                          ? const SizedBox.square(
                                              dimension: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              'Enter ${_selectedRole.label} Portal',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _QuickDemoBar(
                              activeRole: _selectedRole,
                              onDemoSelected: _quickDemoLogin,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    return switch (role) {
      UserRole.student => AppColors.primary,
      UserRole.security => const Color(0xFFD9383A),
      UserRole.parent => const Color(0xFF2E7D32),
      UserRole.staff => const Color(0xFF6A1B9A),
      UserRole.timetableAllocator => const Color(0xFF00695C),
      UserRole.admin => const Color(0xFF263238),
    };
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.selectedRole});

  final UserRole selectedRole;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1E5BB5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'S',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SuperCampus',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'INTEGRATED CAMPUS SYSTEM',
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.onRoleSelected,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: UserRole.values.map((role) {
        final isSelected = selectedRole == role;
        final (icon, color) = _getRoleBadge(role);
        return InkWell(
          onTap: () => onRoleSelected(role),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: isSelected ? color : AppColors.ink,
                        ),
                      ),
                      Text(
                        _getRoleSubLabel(role),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  (IconData, Color) _getRoleBadge(UserRole role) {
    return switch (role) {
      UserRole.student => (Icons.school_outlined, AppColors.primary),
      UserRole.security => (Icons.security_outlined, const Color(0xFFD9383A)),
      UserRole.parent => (
        Icons.family_restroom_outlined,
        const Color(0xFF2E7D32),
      ),
      UserRole.staff => (Icons.badge_outlined, const Color(0xFF6A1B9A)),
      UserRole.timetableAllocator => (
        Icons.table_chart_outlined,
        const Color(0xFF00695C),
      ),
      UserRole.admin => (
        Icons.admin_panel_settings_outlined,
        const Color(0xFF263238),
      ),
    };
  }

  String _getRoleSubLabel(UserRole role) {
    return switch (role) {
      UserRole.student => 'Pass & Canteen',
      UserRole.security => 'Gate Control',
      UserRole.parent => 'Ward Approvals',
      UserRole.staff => 'Classes & Leaves',
      UserRole.timetableAllocator => 'Timetable Control',
      UserRole.admin => 'Access Control',
    };
  }
}

class _QuickDemoBar extends StatelessWidget {
  const _QuickDemoBar({required this.activeRole, required this.onDemoSelected});

  final UserRole activeRole;
  final ValueChanged<UserRole> onDemoSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                '1-Tap Demo Portal Access',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRole.values.map((role) {
              return ActionChip(
                avatar: Icon(
                  _getRoleIcon(role),
                  size: 14,
                  color: activeRole == role ? Colors.white : AppColors.primary,
                ),
                backgroundColor: activeRole == role
                    ? AppColors.primary
                    : Colors.blue.shade50,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: activeRole == role ? Colors.white : AppColors.primary,
                ),
                label: Text('Demo ${role.name.toUpperCase()}'),
                onPressed: () => onDemoSelected(role),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    return switch (role) {
      UserRole.student => Icons.school,
      UserRole.security => Icons.security,
      UserRole.parent => Icons.family_restroom,
      UserRole.staff => Icons.badge,
      UserRole.timetableAllocator => Icons.table_chart,
      UserRole.admin => Icons.admin_panel_settings,
    };
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
