import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../data/auth_repository.dart';
import '../data/login_attempt_limiter.dart';

enum _AuthView { signIn, resetPassword }

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authRepository,
    required this.onSignedIn,
    this.sessionNotice,
    this.attemptLimiter,
  });

  final AuthRepository authRepository;
  final ValueChanged<UserSession> onSignedIn;
  final String? sessionNotice;

  /// Overrides the default persisted limiter, for tests.
  final LoginAttemptLimiter? attemptLimiter;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  _AuthView _view = _AuthView.signIn;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isSuccessLeaving = false;
  String? _errorMessage;
  UserSession? _successSession;
  bool _sessionNoticeShown = false;
  late final LoginAttemptLimiter _attemptLimiter;
  Timer? _lockoutTicker;
  Duration _lockoutRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _attemptLimiter = widget.attemptLimiter ?? LoginAttemptLimiter();
    if (widget.attemptLimiter == null) {
      _attemptLimiter.restore().then((_) {
        if (mounted && _attemptLimiter.isLocked) _startLockoutTicker();
      });
    } else if (_attemptLimiter.isLocked) {
      _startLockoutTicker();
    }
    _showSessionNotice();
  }

  void _startLockoutTicker() {
    _lockoutTicker?.cancel();
    _tickLockout();
    _lockoutTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickLockout(),
    );
  }

  void _tickLockout() {
    if (!mounted) return;
    final remaining = _attemptLimiter.lockoutRemaining;
    setState(() {
      _lockoutRemaining = remaining;
      if (remaining == Duration.zero) {
        _lockoutTicker?.cancel();
        _lockoutTicker = null;
        _errorMessage = null;
      } else {
        _errorMessage = _lockoutMessage(remaining);
      }
    });
  }

  static String _lockoutMessage(Duration remaining) =>
      'Too many incorrect attempts. Try again in '
      '${_formatCountdown(remaining)}, or reset your password.';

  static String _formatCountdown(Duration remaining) {
    // Round up so the countdown never shows 0:00 while still locked.
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return minutes > 0 ? '$minutes:$rest' : '$seconds s';
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionNotice != widget.sessionNotice) {
      _sessionNoticeShown = false;
      _showSessionNotice();
    }
  }

  void _showSessionNotice() {
    final message = widget.sessionNotice;
    if (message == null || message.isEmpty || _sessionNoticeShown) return;
    _sessionNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.devices_rounded, color: Color(0xFF5B21FF)),
          title: const Text('Signed out on this device'),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Okay'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    _emailController.dispose();
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  void _showSignIn() {
    setState(() {
      _view = _AuthView.signIn;
      _errorMessage = _lockoutRemaining > Duration.zero
          ? _lockoutMessage(_lockoutRemaining)
          : null;
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_attemptLimiter.isLocked) {
      _startLockoutTicker();
      return;
    }
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final session = await widget.authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        tenantDomain: '',
      );
      _attemptLimiter.recordSuccess();
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccessLeaving = false;
        _successSession = session;
      });
      if (!reduceMotion) {
        await Future<void>.delayed(const Duration(milliseconds: 1400));
      }
      if (!mounted) return;
      setState(() => _isSuccessLeaving = true);
      if (!reduceMotion) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
      if (mounted) widget.onSignedIn(session);
    } on AuthenticationException catch (error) {
      if (!mounted) return;
      if (!error.invalidCredentials) {
        setState(() => _errorMessage = error.message);
        return;
      }
      final lockout = _attemptLimiter.recordFailure();
      _passwordController.clear();
      if (lockout != null) {
        _startLockoutTicker();
        return;
      }
      final left = _attemptLimiter.attemptsRemaining;
      final lockLength = _formatCountdown(
        _attemptLimiter.lockoutFor(_attemptLimiter.maxFailures),
      );
      setState(() {
        _errorMessage =
            '${error.message} $left ${left == 1 ? 'attempt' : 'attempts'} '
            'left before sign-in locks for $lockLength.';
      });
      _passwordFocusNode.requestFocus();
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
                  _AuthView.signIn => _SignInView(
                    key: const ValueKey('sign-in'),
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    passwordFocusNode: _passwordFocusNode,
                    obscurePassword: _obscurePassword,
                    isSubmitting: _isSubmitting,
                    lockoutRemaining: _lockoutRemaining,
                    errorMessage: _errorMessage,
                    validateEmail: _validateEmail,
                    validatePassword: _validatePassword,
                    onBack: _showSignIn,
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
  late final Animation<double> _watermarkArrival;
  late final Animation<double> _welcomeArrival;
  late final Animation<double> _successArrival;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _watermarkArrival = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.46, curve: Curves.easeOutCubic),
    );
    _welcomeArrival = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.46, curve: Curves.easeOutBack),
    );
    _signatureReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.82, curve: Curves.easeInOutCubic),
    );
    _successArrival = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.67, 1, curve: Curves.easeOutBack),
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
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final sweep = _controller.value;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Transform.translate(
                                offset: Offset(
                                  -54 * (1 - _watermarkArrival.value),
                                  18 * (1 - _watermarkArrival.value),
                                ),
                                child: Opacity(
                                  opacity: 0.20 * _watermarkArrival.value,
                                  child: child,
                                ),
                              ),
                              CustomPaint(painter: _SuccessLightPainter(sweep)),
                            ],
                          );
                        },
                        child: Center(
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
                            AnimatedBuilder(
                              animation: _welcomeArrival,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(
                                  0,
                                  22 * (1 - _welcomeArrival.value),
                                ),
                                child: Opacity(
                                  opacity: _welcomeArrival.value.clamp(0, 1),
                                  child: child,
                                ),
                              ),
                              child: const Text(
                                'Welcome',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w400,
                                  height: 0.9,
                                ),
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
                      child: AnimatedBuilder(
                        animation: _successArrival,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, 20 * (1 - _successArrival.value)),
                          child: Opacity(
                            opacity: _successArrival.value.clamp(0, 1),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CustomPaint(
                                    painter: _SuccessCheckPainter(
                                      _successArrival.value,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                child!,
                              ],
                            ),
                          ),
                        ),
                        child: const Text(
                          'login successful',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.1,
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

class _SuccessLightPainter extends CustomPainter {
  const _SuccessLightPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final x = (progress * 1.75 - 0.38) * size.width;
    final path = Path()
      ..moveTo(x - 110, 0)
      ..lineTo(x + 34, 0)
      ..lineTo(x - 130, size.height)
      ..lineTo(x - 274, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, Color(0x24FFFFFF), Colors.transparent],
        ).createShader(Rect.fromLTWH(x - 280, 0, 320, size.height)),
    );
  }

  @override
  bool shouldRepaint(_SuccessLightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final circlePaint = Paint()..color = const Color(0xFFEDEDED);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      circlePaint,
    );
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0, 1)),
      Paint()
        ..color = const Color(0xFF52565B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
    required this.lockoutRemaining,
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
  final Duration lockoutRemaining;
  final String? errorMessage;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;

  bool get _isLocked => lockoutRemaining > Duration.zero;
  final VoidCallback onBack;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      onBack: onBack,
      showBack: false,
      child: AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 36),
              const Text(
                'SuperCampus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Brittany',
                  fontSize: 34,
                  color: Color(0xFF18181B),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'login to your account issued by your instituition',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 40),
              _FieldLabel(
                label: 'Email address',
                child: TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF18181B),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFA1A1AA),
                    ),
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFF71717A),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE4E4E7),
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 1.8,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.2,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.8,
                      ),
                    ),
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
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF18181B),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFA1A1AA),
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF71717A),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF71717A),
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE4E4E7),
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 1.8,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.2,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.8,
                      ),
                    ),
                  ),
                  validator: validatePassword,
                  onFieldSubmitted: (_) {
                    if (!isSubmitting && !_isLocked) onSubmit();
                  },
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isSubmitting ? null : onForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: errorMessage!),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 20),
              if (isSubmitting)
                const SkeletonBox(
                  height: 52,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                )
              else
                FilledButton(
                  onPressed: _isLocked ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18181B),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE4E4E7),
                    disabledForegroundColor: const Color(0xFF71717A),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isLocked
                        ? 'Locked · '
                              '${_LoginScreenState._formatCountdown(lockoutRemaining)}'
                        : 'Sign in',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              const Text(
                'Your access and campus services are managed by your institution administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF71717A),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
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
      showBack: false,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD9D9D9),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              'Reset your password',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF18181B),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter your registered email address. We will send instructions to regain access.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF71717A),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _FieldLabel(
              label: 'Email address',
              child: TextFormField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF18181B),
                ),
                decoration: InputDecoration(
                  hintText: 'name@college.edu',
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFA1A1AA),
                  ),
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: Color(0xFF71717A),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE4E4E7),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.8,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.8,
                    ),
                  ),
                ),
                validator: validateEmail,
                onFieldSubmitted: (_) {
                  if (!isSubmitting) onSubmit();
                },
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: errorMessage!),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 24),
            if (isSubmitting)
              const SkeletonBox(
                height: 52,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              )
            else
              FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Send reset link',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PasswordResetCompletionScreen extends StatefulWidget {
  const PasswordResetCompletionScreen({
    super.key,
    required this.token,
    required this.onResetPassword,
    required this.onBackToLogin,
  });

  final String? token;
  final Future<void> Function(String token, String password) onResetPassword;
  final VoidCallback onBackToLogin;

  @override
  State<PasswordResetCompletionScreen> createState() =>
      _PasswordResetCompletionScreenState();
}

class _PasswordResetCompletionScreenState
    extends State<PasswordResetCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Create a new password.';
    if (password.characters.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (utf8.encode(password).length > 72) {
      return 'Password must be at most 72 bytes.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your new password.';
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage =
            'This reset link is incomplete. Request a new link from sign in.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onResetPassword(token, _passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Sign in with your new password.'),
        ),
      );
      widget.onBackToLogin();
    } on AuthenticationException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'We could not update your password. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingToken = widget.token?.trim().isEmpty ?? true;
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 60,
                ),
                child: Center(
                  child: SizedBox(
                    width: 440,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandLockup(centered: true),
                        const SizedBox(height: 34),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x120E00B8),
                                blurRadius: 30,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.violetGradient,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.lock_reset_rounded,
                                      color: Colors.white,
                                      size: 27,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Create new password',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF18181B),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                const Text(
                                  'Choose a secure password for your SuperCampus account.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF71717A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                _FieldLabel(
                                  label: 'New password',
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF18181B),
                                    ),
                                    validator: _validatePassword,
                                    decoration: InputDecoration(
                                      hintText: 'At least 8 characters',
                                      hintStyle: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFFA1A1AA),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        color: Color(0xFF71717A),
                                        size: 20,
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
                                          color: const Color(0xFF71717A),
                                          size: 20,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE4E4E7),
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF6366F1),
                                          width: 1.8,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _FieldLabel(
                                  label: 'Confirm password',
                                  child: TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmation,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF18181B),
                                    ),
                                    validator: _validateConfirmation,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      hintText: 'Enter it again',
                                      hintStyle: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFFA1A1AA),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.verified_user_outlined,
                                        color: Color(0xFF71717A),
                                        size: 20,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _obscureConfirmation
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () => setState(
                                          () => _obscureConfirmation =
                                              !_obscureConfirmation,
                                        ),
                                        icon: Icon(
                                          _obscureConfirmation
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: const Color(0xFF71717A),
                                          size: 20,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE4E4E7),
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF6366F1),
                                          width: 1.8,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (missingToken || _errorMessage != null) ...[
                                  const SizedBox(height: 18),
                                  _ErrorBanner(
                                    message: _errorMessage ??
                                        'This reset link is incomplete. Request a new link from sign in.',
                                  ),
                                ],
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed:
                                      _isSubmitting || missingToken ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF18181B),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Create password',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: widget.onBackToLogin,
                                  child: const Text(
                                    'Back to login',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.onBack,
    required this.child,
    this.showBack = false,
  });

  final VoidCallback onBack;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
            child: Center(
              child: SizedBox(
                width: 440,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showBack) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: onBack,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD9D9D9),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const SizedBox(height: 16),
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
        SizedBox(
          width: 38,
          height: 38,
          child: Image.asset(
            'assets/branding/supercampus_app_icon.png',
            fit: BoxFit.contain,
            semanticLabel: 'SuperCampus logo',
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SuperCampus',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            Text(
              'INTEGRATED CAMPUS SYSTEM',
              style: TextStyle(
                fontFamily: 'Poppins',
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
            fontFamily: 'Poppins',
            color: Color(0xFF18181B),
            fontSize: 13.5,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
