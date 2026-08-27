import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../data/auth_repository.dart';

enum _AuthView { welcome, institution, signIn, resetPassword }

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
  final _institutionFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _institutionController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  _AuthView _view = _AuthView.welcome;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isSuccessLeaving = false;
  String? _errorMessage;
  UserSession? _successSession;

  @override
  void dispose() {
    _emailController.dispose();
    _institutionController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
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

  String? _validateIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) return 'Enter your email address or mobile number.';
    final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(identifier);
    final phoneDigits = identifier.replaceAll(RegExp(r'\D'), '');
    if (identifier.contains('@')) {
      return isEmail ? null : 'Enter a valid email address or mobile number.';
    }
    return phoneDigits.length >= 10 && phoneDigits.length <= 15
        ? null
        : 'Enter a valid email address or mobile number.';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String? _validateInstitution(String? value) {
    final institution = value?.trim().toLowerCase() ?? '';
    if (institution.isEmpty) return 'Enter your institution domain.';
    if (!RegExp(
      r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
    ).hasMatch(institution)) {
      return 'Use only letters, numbers, or hyphens.';
    }
    return null;
  }

  void _showInstitution() {
    setState(() {
      _view = _AuthView.institution;
      _errorMessage = null;
    });
  }

  void _showSignIn() {
    FocusScope.of(context).unfocus();
    if (!_institutionFormKey.currentState!.validate()) return;
    _institutionController.text = _institutionController.text
        .trim()
        .toLowerCase();
    setState(() {
      _view = _AuthView.signIn;
      _errorMessage = null;
    });
  }

  void _showResetPassword() {
    _resetEmailController.text = _emailController.text.trim();
    setState(() {
      _view = _AuthView.resetPassword;
      _errorMessage = null;
    });
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
        tenantDomain: _institutionController.text,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccessLeaving = false;
        _successSession = session;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() => _isSuccessLeaving = true);
      await Future<void>.delayed(const Duration(milliseconds: 180));
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

  Future<void> _sendPasswordReset() async {
    FocusScope.of(context).unfocus();
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final email = _resetEmailController.text.trim();
    try {
      await widget.authRepository.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A reset link has been sent to $email.')),
      );
      _emailController.text = email;
      _showSignIn();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'We could not send the reset link. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (_view) {
                  _AuthView.welcome => _WelcomeView(
                    key: const ValueKey('welcome'),
                    onContinue: _showInstitution,
                  ),
                  _AuthView.institution => _InstitutionView(
                    key: const ValueKey('institution'),
                    formKey: _institutionFormKey,
                    controller: _institutionController,
                    validateInstitution: _validateInstitution,
                    onBack: () => setState(() => _view = _AuthView.welcome),
                    onContinue: _showSignIn,
                  ),
                  _AuthView.signIn => _SignInView(
                    key: const ValueKey('sign-in'),
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    passwordFocusNode: _passwordFocusNode,
                    obscurePassword: _obscurePassword,
                    isSubmitting: _isSubmitting,
                    errorMessage: _errorMessage,
                    validateEmail: _validateIdentifier,
                    validatePassword: _validatePassword,
                    onBack: () => setState(() => _view = _AuthView.institution),
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onForgotPassword: _showResetPassword,
                    onSubmit: _submit,
                  ),
                  _AuthView.resetPassword => _ResetPasswordView(
                    key: const ValueKey('reset-password'),
                    formKey: _resetFormKey,
                    emailController: _resetEmailController,
                    isSubmitting: _isSubmitting,
                    errorMessage: _errorMessage,
                    validateEmail: _validateEmail,
                    onBack: _showSignIn,
                    onSubmit: _sendPasswordReset,
                  ),
                },
              ),
            ),
            if (_successSession case final session?)
              _LoginSuccessSplash(
                firstName: _firstNameFromSession(session),
                isLeaving: _isSuccessLeaving,
              ),
          ],
        ),
      ),
    );
  }

  String _firstNameFromSession(UserSession session) {
    final fromName = session.displayName.trim();
    if (fromName.isNotEmpty) return fromName.split(RegExp(r'\s+')).first;
    final fromEmail = session.email.split('@').first.trim();
    if (fromEmail.isEmpty) return 'there';
    return fromEmail.split(RegExp(r'[._-]+')).first;
  }
}

class _LoginSuccessSplash extends StatefulWidget {
  const _LoginSuccessSplash({required this.firstName, required this.isLeaving});

  final String firstName;
  final bool isLeaving;

  @override
  State<_LoginSuccessSplash> createState() => _LoginSuccessSplashState();
}

class _LoginSuccessSplashState extends State<_LoginSuccessSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _signatureReveal;
  late final Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _signatureReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.04, 0.96, curve: Curves.easeInOutCubic),
    );
    _footerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          opacity: widget.isLeaving ? 0 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final nameWidth = (widget.firstName.length * 34.0).clamp(
                150.0,
                constraints.maxWidth - 72,
              );
              final centerOffset = constraints.maxHeight * 0.02;

              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4200FF),
                      Color(0xFF7000FF),
                      Color(0xFF9600FF),
                    ],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Opacity(
                          opacity: 0.20,
                          child: FractionallySizedBox(
                            widthFactor: 1.54,
                            child: Image.asset(
                              'assets/images/login_success_watermark.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, centerOffset),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Welcome',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w400,
                                height: 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: nameWidth,
                              height: 62,
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: _signatureReveal,
                                  builder: (context, child) {
                                    return ClipRect(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _signatureReveal.value
                                            .clamp(0.001, 1.0),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    widget.firstName,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Brittany',
                                      fontFamilyFallback: [
                                        'Poppins',
                                        'cursive',
                                      ],
                                      fontSize: 46,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: -1.1,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: constraints.maxHeight * 0.08,
                      child: FadeTransition(
                        opacity: _footerOpacity,
                        child: const Text(
                          'login successful',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 700;
        return Column(
          children: [
            Expanded(
              flex: compact ? 5 : 6,
              child: _CampusCanvas(compact: compact),
            ),
            Expanded(
              flex: compact ? 4 : 5,
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, compact ? 22 : 34, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandLockup(centered: false),
                    const Spacer(),
                    Text(
                      'Your campus, in one place.',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: compact ? 27 : 31,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Academics, attendance and campus services connected to your institution account.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('start-sign-in'),
                      onPressed: onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Continue to sign in'),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CampusCanvas extends StatelessWidget {
  const _CampusCanvas({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CanvasClipper(),
      child: ColoredBox(
        color: const Color(0xFF10182B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _CampusGridPainter()),
            Center(
              child: Transform.translate(
                offset: Offset(0, compact ? 0 : 8),
                child: const _CampusIllustration(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusIllustration extends StatelessWidget {
  const _CampusIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 156,
            height: 156,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              size: 49,
              color: Color(0xFF10182B),
            ),
          ),
          const Positioned(
            left: 17,
            top: 38,
            child: _OrbitIcon(icon: Icons.school_outlined),
          ),
          const Positioned(
            right: 12,
            top: 54,
            child: _OrbitIcon(icon: Icons.badge_outlined),
          ),
          const Positioned(
            left: 34,
            bottom: 18,
            child: _OrbitIcon(icon: Icons.calendar_month_outlined),
          ),
          const Positioned(
            right: 31,
            bottom: 10,
            child: _OrbitIcon(icon: Icons.qr_code_rounded),
          ),
        ],
      ),
    );
  }
}

class _OrbitIcon extends StatelessWidget {
  const _OrbitIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF1D2942),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, size: 21, color: Colors.white),
    );
  }
}

class _InstitutionView extends StatelessWidget {
  const _InstitutionView({
    super.key,
    required this.formKey,
    required this.controller,
    required this.validateInstitution,
    required this.onBack,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String? Function(String?) validateInstitution;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      onBack: onBack,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 54),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F2F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Find your institution',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 29,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter the domain provided by your institution administrator.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 34),
            _FieldLabel(
              label: 'Institution domain',
              child: TextFormField(
                key: const ValueKey('institution-domain'),
                controller: controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'mec',
                  prefixIcon: Icon(Icons.language_rounded),
                  suffixText: '.supercampus.ai',
                ),
                validator: validateInstitution,
                onFieldSubmitted: (_) => onContinue(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Example: enter mec for mec.supercampus.ai',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const ValueKey('continue-from-institution'),
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue'),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 19),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.errorMessage,
    required this.validateEmail,
    required this.validatePassword,
    required this.onBack,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final bool isSubmitting;
  final String? errorMessage;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;
  final VoidCallback onBack;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      onBack: onBack,
      child: AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the account issued by your institution.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 34),
              _FieldLabel(
                label: 'Email address or mobile number',
                child: TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    hintText: 'name@college.edu or mobile number',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: validateEmail,
                  onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
                ),
              ),
              const SizedBox(height: 20),
              _FieldLabel(
                label: 'Password',
                child: TextFormField(
                  controller: passwordController,
                  focusNode: passwordFocusNode,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: validatePassword,
                  onFieldSubmitted: (_) {
                    if (!isSubmitting) onSubmit();
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isSubmitting ? null : onForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(message: errorMessage!),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 14),
              if (isSubmitting)
                const SkeletonBox(
                  height: 54,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                )
              else
                FilledButton(
                  onPressed: onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Text('Sign in'),
                ),
              const SizedBox(height: 18),
              Text(
                'Your access and campus services are managed by your institution administrator.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordView extends StatelessWidget {
  const _ResetPasswordView({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.isSubmitting,
    required this.errorMessage,
    required this.validateEmail,
    required this.onBack,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSubmitting;
  final String? errorMessage;
  final String? Function(String?) validateEmail;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      onBack: onBack,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 64),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F2F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.key_rounded, color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Reset your password',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 29,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your registered email address. We will send instructions to regain access.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 34),
            _FieldLabel(
              label: 'Email address',
              child: TextFormField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'name@college.edu',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: validateEmail,
                onFieldSubmitted: (_) {
                  if (!isSubmitting) onSubmit();
                },
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 18),
              _ErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: 24),
            if (isSubmitting)
              const SkeletonBox(
                height: 54,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              )
            else
              FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Send reset link'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Center(
              child: SizedBox(
                width: 440,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.centered});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SuperCampus',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            Text(
              'INTEGRATED CAMPUS SYSTEM',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 8,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A1C13),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 44)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 28,
        size.width,
        size.height - 44,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CampusGridPainter extends CustomPainter {
  const _CampusGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const gap = 34.0;
    for (var x = 0.0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
