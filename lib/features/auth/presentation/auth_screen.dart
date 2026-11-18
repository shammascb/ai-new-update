import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firebase_auth_service.dart';

enum _AuthMode { signIn, register, resetPassword }

const _authCanvas = Color(0xFFE9E8F2);
const _authPanel = Color(0xFF11111B);
const _authField = Color(0xFF1E1E2A);
const _authAccent = Color(0xFF6957FF);
const _authMuted = Color(0xFFAAA9BA);

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.authService,
    required this.backendMessage,
    required this.isDarkMode,
    required this.onThemeToggle,
    super.key,
  });

  final FirebaseAuthService? authService;
  final String? backendMessage;
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  bool _passwordVisible = false;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (_mode == _AuthMode.register && value.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  Future<void> _signInWithGoogle() async {
    final authService = widget.authService;
    if (authService == null) {
      setState(() {
        _notice = widget.backendMessage ??
            'Authentication is unavailable until Firebase is configured.';
        _noticeIsError = true;
      });
      return;
    }

    setState(() {
      _isGoogleSubmitting = true;
      _notice = null;
    });

    try {
      await authService.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _notice = authenticationErrorMessage(error);
        _noticeIsError = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notice = 'Google sign-in failed: $error';
        _noticeIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authService = widget.authService;
    if (authService == null) {
      setState(() {
        _notice = widget.backendMessage ??
            'Authentication is unavailable until Firebase is configured.';
        _noticeIsError = true;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _notice = null;
    });

    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await authService.signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
          break;
        case _AuthMode.register:
          await authService.register(
            displayName: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
          break;
        case _AuthMode.resetPassword:
          await authService.sendPasswordReset(_emailController.text);
          if (!mounted) return;
          setState(() {
            _mode = _AuthMode.signIn;
            _notice =
                'If an account exists for that email, a reset link was sent.';
            _noticeIsError = false;
          });
          break;
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _notice = authenticationErrorMessage(error);
        _noticeIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _notice = null;
      _formKey.currentState?.reset();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 19, color: _authMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _authField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: const TextStyle(color: _authMuted, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: _authAccent),
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _authAccent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF7777)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF7777), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _AuthMode.signIn => 'Welcome Back!',
      _AuthMode.register => 'Create Account',
      _AuthMode.resetPassword => 'Reset Password',
    };
    final busy = _isSubmitting || _isGoogleSubmitting;

    return Scaffold(
      backgroundColor: _authCanvas,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _AuthBackdropPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20, top: 4),
                    child: IconButton(
                      tooltip: widget.isDarkMode
                          ? 'Switch to light theme'
                          : 'Switch to dark theme',
                      onPressed: widget.onThemeToggle,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                        foregroundColor: _authPanel,
                      ),
                      icon: Icon(
                        widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _authPanel,
                              border: Border.all(
                                color: _authAccent.withValues(alpha: 0.32),
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: _authAccent.withValues(alpha: 0.16),
                                  blurRadius: 38,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -54,
                                  right: -42,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          _authAccent.withValues(alpha: 0.12),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -72,
                                  right: 12,
                                  child: Container(
                                    width: 190,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          _authAccent.withValues(alpha: 0.08),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(26),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _authAccent,
                                            ),
                                            child: const Icon(
                                              Icons.home_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'AI Home Brain',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'SMART HOME ASSISTANT',
                                                style: TextStyle(
                                                  color: _authMuted.withValues(
                                                    alpha: 0.8,
                                                  ),
                                                  fontSize: 9,
                                                  letterSpacing: 1.2,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 26),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 27,
                                          height: 1.1,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _mode == _AuthMode.register
                                            ? 'Create a secure account to access your home.'
                                            : _mode == _AuthMode.resetPassword
                                                ? 'We’ll email you a secure password reset link.'
                                                : 'Sign in with Google or your email and password to continue.',
                                        style: const TextStyle(
                                          color: _authMuted,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      if (widget.authService == null) ...[
                                        _MessageCard(
                                          message: widget.backendMessage ??
                                              'Firebase Authentication is not connected.',
                                          isError: true,
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                      if (_mode != _AuthMode.resetPassword) ...[
                                        FilledButton.icon(
                                          onPressed:
                                              busy ? null : _signInWithGoogle,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: _authPanel,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: _isGoogleSubmitting
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: _authPanel,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.login_rounded,
                                                  size: 19,
                                                ),
                                          label: const Text(
                                            'Continue with Google',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Divider(
                                                color: Colors.white
                                                    .withValues(alpha: 0.12),
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                'or with email',
                                                style: TextStyle(
                                                  color: _authMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                color: Colors.white
                                                    .withValues(alpha: 0.12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      if (_notice != null) ...[
                                        _MessageCard(
                                          message: _notice!,
                                          isError: _noticeIsError,
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                      Form(
                                        key: _formKey,
                                        child: Column(
                                          children: [
                                            if (_mode ==
                                                _AuthMode.register) ...[
                                              TextFormField(
                                                controller: _nameController,
                                                textCapitalization:
                                                    TextCapitalization.words,
                                                textInputAction:
                                                    TextInputAction.next,
                                                autofillHints: const [
                                                  AutofillHints.name,
                                                ],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                                decoration: _inputDecoration(
                                                  'Full name',
                                                  Icons.person_outline,
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.trim().isEmpty) {
                                                    return 'Enter your name.';
                                                  }
                                                  if (value.trim().length < 2) {
                                                    return 'Name must be at least 2 characters.';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 13),
                                            ],
                                            TextFormField(
                                              controller: _emailController,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              textInputAction: _mode ==
                                                      _AuthMode.resetPassword
                                                  ? TextInputAction.done
                                                  : TextInputAction.next,
                                              autofillHints: const [
                                                AutofillHints.email,
                                              ],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                              decoration: _inputDecoration(
                                                'Email',
                                                Icons.mail_outline_rounded,
                                              ),
                                              validator: _validateEmail,
                                            ),
                                            if (_mode !=
                                                _AuthMode.resetPassword) ...[
                                              const SizedBox(height: 13),
                                              TextFormField(
                                                controller: _passwordController,
                                                obscureText: !_passwordVisible,
                                                textInputAction:
                                                    _mode == _AuthMode.register
                                                        ? TextInputAction.next
                                                        : TextInputAction.done,
                                                autofillHints: _mode ==
                                                        _AuthMode.register
                                                    ? const [
                                                        AutofillHints
                                                            .newPassword,
                                                      ]
                                                    : const [
                                                        AutofillHints.password,
                                                      ],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                                decoration: _inputDecoration(
                                                  'Password',
                                                  Icons.lock_outline_rounded,
                                                  suffixIcon: IconButton(
                                                    tooltip: _passwordVisible
                                                        ? 'Hide password'
                                                        : 'Show password',
                                                    onPressed: () => setState(
                                                      () => _passwordVisible =
                                                          !_passwordVisible,
                                                    ),
                                                    icon: Icon(
                                                      _passwordVisible
                                                          ? Icons
                                                              .visibility_off_outlined
                                                          : Icons
                                                              .visibility_outlined,
                                                      color: _authMuted,
                                                      size: 19,
                                                    ),
                                                  ),
                                                ),
                                                validator: _validatePassword,
                                              ),
                                            ],
                                            if (_mode ==
                                                _AuthMode.register) ...[
                                              const SizedBox(height: 13),
                                              TextFormField(
                                                controller:
                                                    _confirmPasswordController,
                                                obscureText: !_passwordVisible,
                                                textInputAction:
                                                    TextInputAction.done,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                                decoration: _inputDecoration(
                                                  'Confirm password',
                                                  Icons.lock_outline_rounded,
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Confirm your password.';
                                                  }
                                                  if (value !=
                                                      _passwordController
                                                          .text) {
                                                    return 'Passwords do not match.';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                            const SizedBox(height: 18),
                                            if (_mode == _AuthMode.signIn)
                                              Row(
                                                children: [
                                                  TextButton(
                                                    onPressed: () => _setMode(
                                                      _AuthMode.resetPassword,
                                                    ),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          _authMuted,
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                    child: const Text(
                                                      'Forgot password?',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  _submitButton(busy),
                                                ],
                                              )
                                            else
                                              SizedBox(
                                                width: double.infinity,
                                                child: _submitButton(busy),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      if (_mode == _AuthMode.resetPassword)
                                        TextButton(
                                          onPressed: () =>
                                              _setMode(_AuthMode.signIn),
                                          style: TextButton.styleFrom(
                                            foregroundColor: _authMuted,
                                          ),
                                          child: const Text('Back to sign in'),
                                        )
                                      else
                                        TextButton(
                                          onPressed: () => _setMode(
                                            _mode == _AuthMode.signIn
                                                ? _AuthMode.register
                                                : _AuthMode.signIn,
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: _authMuted,
                                          ),
                                          child: Text(
                                            _mode == _AuthMode.signIn
                                                ? 'New here? Create an account'
                                                : 'Already have an account? Sign in',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Secure access for your home and family.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _authMuted.withValues(
                                              alpha: 0.75),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton(bool busy) {
    final label = switch (_mode) {
      _AuthMode.signIn => 'Sign in',
      _AuthMode.register => 'Create account',
      _AuthMode.resetPassword => 'Send reset link',
    };

    return FilledButton(
      onPressed: busy ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: _authAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
    );
  }
}

class _AuthBackdropPainter extends CustomPainter {
  const _AuthBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final circlePaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(size.width * 1.03, size.height * 0.08),
      size.width * 0.26,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * -0.07, size.height * 0.82),
      size.width * 0.23,
      circlePaint,
    );

    final dotPaint = Paint()
      ..color = _authAccent.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    for (var x = size.width * 0.09; x < size.width * 0.38; x += 8) {
      for (var y = size.height * 0.08; y < size.height * 0.19; y += 8) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFFB7B6C5).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var offset = -size.width; offset < size.width; offset += 10) {
      canvas.drawLine(
        Offset(size.width * 0.62 + offset, size.height * 0.9),
        Offset(size.width * 0.78 + offset, size.height * 0.78),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuthBackdropPainter oldDelegate) => false;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? colorScheme.error : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
