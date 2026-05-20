import 'package:flutter/material.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_state/forge_state.dart';
import 'package:forge_backend/forge_backend.dart';
import 'package:forge_ui/config/forge_ui_config.dart';

enum AuthMode { signIn, signUp }

class ForgeLoginScreen extends ConsumerStatefulWidget {
  final void Function(AuthUserDetails user)? onAuthSuccess;
  final void Function(String error)? onAuthFailure;
  final String? title;
  final String? subtitle;
  final Widget? logo;
  final bool showSocialLogins;
  final ForgeLoginConfig? config;

  const ForgeLoginScreen({
    super.key,
    this.onAuthSuccess,
    this.onAuthFailure,
    this.title,
    this.subtitle,
    this.logo,
    this.showSocialLogins = true,
    this.config,
  });

  @override
  ConsumerState<ForgeLoginScreen> createState() => _ForgeLoginScreenState();
}

class _ForgeLoginScreenState extends ConsumerState<ForgeLoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  AuthMode _authMode = AuthMode.signIn;
  
  late final TabController _tabController;

  ForgeLoginConfig _resolveConfig() {
    if (widget.config != null) return widget.config!;
    try {
      if (GetIt.instance.isRegistered<ForgeUIConfig>()) {
        return GetIt.instance<ForgeUIConfig>().login;
      }
    } catch (_) {}
    return const ForgeLoginConfig();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _authMode = _tabController.index == 0 ? AuthMode.signIn : AuthMode.signUp;
        });
        Analytics.track('auth_mode_switched', {
          'mode': _authMode.name,
        });
      }
    });

    Analytics.track('forge_login_screen_viewed', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _contactNumberController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (widget.onAuthFailure != null) {
      widget.onAuthFailure!(message);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    
    Analytics.track('auth_submit_initiated', {
      'mode': _authMode.name,
      'email': email,
    });

    try {
      final authNotifier = ref.read(authStateProvider.notifier);

      if (_authMode == AuthMode.signIn) {
        await authNotifier.signInWithEmail(email, password);
      } else {
        await authNotifier.signUpWithEmail(
          email, 
          password,
          name: _resolveConfig().requireName ? _nameController.text.trim() : null,
          contactNumber: _resolveConfig().requireContactNumber ? _contactNumberController.text.trim() : null,
        );
      }

      // Check new state
      final authState = ref.read(authStateProvider).valueOrNull;
      if (authState is AuthAuthenticated) {
        Analytics.track('auth_submit_success', {
          'mode': _authMode.name,
          'user_id': authState.user.id,
        });

        _showSuccess(_authMode == AuthMode.signIn ? 'Welcome back!' : 'Account created successfully!');
        if (widget.onAuthSuccess != null) {
          widget.onAuthSuccess!(authState.user);
        }
      } else if (authState is AuthError) {
        Analytics.track('auth_submit_failed', {
          'mode': _authMode.name,
          'error': authState.message,
        });
        _showError(authState.message);
      }
    } catch (e) {
      Analytics.track('auth_submit_failed', {
        'mode': _authMode.name,
        'error': e.toString(),
      });
      _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    Analytics.track('google_auth_initiated', {});

    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      await authNotifier.signInWithGoogle();

      final authState = ref.read(authStateProvider).valueOrNull;
      if (authState is AuthAuthenticated) {
        Analytics.track('google_auth_success', {
          'user_id': authState.user.id,
        });

        _showSuccess('Google Sign-In successful!');
        if (widget.onAuthSuccess != null) {
          widget.onAuthSuccess!(authState.user);
        }
      } else if (authState is AuthError) {
        Analytics.track('google_auth_failed', {
          'error': authState.message,
        });
        _showError(authState.message);
      }
    } catch (e) {
      Analytics.track('google_auth_failed', {
        'error': e.toString(),
      });
      _showError('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    Analytics.track('apple_auth_initiated', {});

    try {
      // BackendService might support Apple, but authStateProvider doesn't have signInWithApple.
      // Let's interact with BackendService directly via GetIt to stay super solid and robust!
      final backend = GetIt.instance<BackendService>();
      final result = await backend.signInWithApple();

      result.fold(
        (failure) {
          Analytics.track('apple_auth_failed', {
            'error': failure.message,
          });
          _showError(failure.message);
        },
        (user) {
          Analytics.track('apple_auth_success', {
            'user_id': user.id,
          });
          
          // Manually update Riverpod authState if needed, or backend service changes will stream it
          _showSuccess('Apple Sign-In successful!');
          if (widget.onAuthSuccess != null) {
            widget.onAuthSuccess!(user);
          }
        },
      );
    } catch (e) {
      Analytics.track('apple_auth_failed', {
        'error': e.toString(),
      });
      _showError('Apple Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background sophisticated gradients
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surface,
                    // ignore: deprecated_member_use
                    theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          
          // Glassmorphic background decorative circles
          Positioned(
            top: -60,
            left: -60,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: primaryColor.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -80,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.05),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand / Logo area
                    if (widget.logo != null) ...[
                      Center(child: widget.logo!),
                      const SizedBox(height: 24),
                    ] else ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, theme.colorScheme.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: Icon(
                            _resolveConfig().logoIcon,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Title & Subtitle
                    Text(
                      widget.title ?? _resolveConfig().title ?? (_authMode == AuthMode.signIn ? 'Welcome Back' : 'Create Account'),
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle ?? _resolveConfig().subtitle ?? (_authMode == AuthMode.signIn 
                          ? 'Enter your credentials to access your dashboard' 
                          : 'Join us and start building premium applications today'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Slidder Tab bar for Sign In / Sign Up
                    if (_resolveConfig().allowSignUp) ...[
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: primaryColor,
                          unselectedLabelColor: theme.colorScheme.outline,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Sign Up'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Form inputs
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_authMode == AuthMode.signUp && _resolveConfig().requireName) ...[
                            TextFormField(
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)),
                              ),
                              validator: (val) {
                                if (_authMode == AuthMode.signUp && _resolveConfig().requireName) {
                                  if (val == null || val.trim().isEmpty) return 'Full Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (_authMode == AuthMode.signUp && _resolveConfig().requireContactNumber) ...[
                            TextFormField(
                              controller: _contactNumberController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Contact Number (e.g. +1 123 456 7890)',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)),
                              ),
                              validator: (val) {
                                if (_authMode == AuthMode.signUp && _resolveConfig().requireContactNumber) {
                                  if (val == null || val.trim().isEmpty) return 'Contact Number is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Email is required';
                              }
                              final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!regex.hasMatch(val.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Password is required';
                              }
                              if (val.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          
                          // Conditionally show Confirm Password in Sign Up mode
                          if (_authMode == AuthMode.signUp) ...[
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_clock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                              ),
                              validator: (val) {
                                if (_authMode == AuthMode.signUp) {
                                  if (val == null || val.isEmpty) {
                                    return 'Confirm password is required';
                                  }
                                  if (val != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],

                          if (_authMode == AuthMode.signIn && _resolveConfig().allowForgotPassword) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Custom recovery actions
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Password reset flow not implemented.')),
                                  );
                                },
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                          ],

                          const SizedBox(height: 12),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _authMode == AuthMode.signIn ? 'Sign In' : 'Create Account',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Social login divider and options
                    if (widget.showSocialLogins &&
                        _resolveConfig().showSocialLogins &&
                        (_resolveConfig().allowGoogleLogin || _resolveConfig().allowAppleLogin)) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Or continue with',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          if (_resolveConfig().allowGoogleLogin)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Google'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                            ),
                          if (_resolveConfig().allowGoogleLogin && _resolveConfig().allowAppleLogin)
                            const SizedBox(width: 16),
                          if (_resolveConfig().allowAppleLogin)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleAppleSignIn,
                                icon: const Icon(Icons.apple, size: 24),
                                label: const Text('Apple'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
