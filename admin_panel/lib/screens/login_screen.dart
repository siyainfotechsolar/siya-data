import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import 'dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const String _prefKeyRememberPassword = 'siya_admin_remember_password';
  static const String _prefKeySavedEmail = 'siya_admin_saved_email';
  static const String _prefKeySavedPassword = 'siya_admin_saved_password';

  bool _rememberPassword = true;
  bool _isLoading = false;
  String _loadingMessage = 'Signing In...';
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _validateExistingSession();
  }

  /// Loads remembered email and password if available
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_prefKeyRememberPassword) ?? true;
      if (remember) {
        final savedEmail = prefs.getString(_prefKeySavedEmail) ?? '';
        final savedPassword = prefs.getString(_prefKeySavedPassword) ?? '';
        if (mounted) {
          setState(() {
            _rememberPassword = true;
            if (savedEmail.isNotEmpty && _emailController.text.isEmpty) {
              _emailController.text = savedEmail;
            }
            if (savedPassword.isNotEmpty && _passwordController.text.isEmpty) {
              _passwordController.text = savedPassword;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _rememberPassword = false;
          });
        }
      }
    } catch (_) {
      // Non-fatal if SharedPreferences is unavailable
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Automatically validates existing session on screen load
  Future<void> _validateExistingSession() async {
    if (SupabaseService.isAuthenticated && SupabaseService.hasValidSession) {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Validating Session...';
      });

      try {
        final profile = await SupabaseService.fetchProfile();
        if (profile != null) {
          final status = (profile['status'] as String? ?? 'Active').toLowerCase();
          final isActive = profile['is_active'] as bool? ?? true;

          if (status == 'inactive' || status == 'suspended' || !isActive) {
            await SupabaseService.signOut();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Your account is inactive. Please contact Admin.';
              });
            }
            return;
          }
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        }
      } catch (_) {
        await SupabaseService.signOut();
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (SupabaseService.isAuthenticated && !SupabaseService.hasValidSession) {
      await SupabaseService.signOut();
    }
  }

  /// Maps Supabase/system exceptions to user-friendly messages
  String _mapAuthError(Object error) {
    if (error is SocketException) {
      return 'Unable to connect. Please check your internet connection.';
    }

    final str = error.toString().toLowerCase();

    if (str.contains('inactive') || str.contains('suspended') || str.contains('account is inactive')) {
      return 'Your account is inactive. Please contact Admin.';
    }

    if (str.contains('invalid login credentials') ||
        str.contains('invalid_credentials') ||
        str.contains('invalid_grant') ||
        str.contains('invalid email or password') ||
        str.contains('wrong password') ||
        str.contains('user not found')) {
      return 'Invalid email or password.';
    }

    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network') ||
        str.contains('connection') ||
        str.contains('client offline') ||
        str.contains('timeout') ||
        str.contains('failed to connect') ||
        str.contains('handshake') ||
        str.contains('xmlhttprequest error')) {
      return 'Unable to connect. Please check your internet connection.';
    }

    return error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('AuthException: ', '');
  }

  /// Production Login Behavior:
  /// Email + Password -> Supabase Auth -> Validate Session -> Load Profile ->
  /// Check Account Status -> Load Role & Permissions -> Admin Dashboard
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Signing In...';
      _errorMessage = null;
    });

    try {
      // 1. Supabase Authentication
      final authResponse = await SupabaseService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Invalid email or password.');
      }

      // 2. Validate Session
      final session = SupabaseService.currentSession;
      if (session == null || session.isExpired) {
        throw Exception('Session validation failed. Please try again.');
      }

      // 3. Load User Profile
      if (mounted) {
        setState(() {
          _loadingMessage = 'Loading Profile...';
        });
      }

      final profile = await SupabaseService.fetchProfile(user.id);

      // 4. Check Account Status
      if (profile != null) {
        final status = (profile['status'] as String? ?? 'Active').toLowerCase();
        final isActive = profile['is_active'] as bool? ?? true;

        if (status == 'inactive' || status == 'suspended' || !isActive) {
          await SupabaseService.signOut();
          await SupabaseService.logAuthAudit(
            action: 'LOGIN_BLOCKED_INACTIVE',
            email: email,
            userId: user.id,
            details: 'Account status: $status, is_active: $isActive',
          );
          throw Exception('Your account is inactive. Please contact Admin.');
        }
      }

      // 5. Load Role & Permissions
      if (mounted) {
        setState(() {
          _loadingMessage = 'Loading Permissions...';
        });
      }

      // Audit successful login
      await SupabaseService.logAuthAudit(
        action: 'LOGIN_SUCCESS',
        email: email,
        userId: user.id,
        details: 'Admin web portal login successful',
      );

      // Save or clear credentials based on Remember Password preference
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberPassword) {
          await prefs.setBool(_prefKeyRememberPassword, true);
          await prefs.setString(_prefKeySavedEmail, email);
          await prefs.setString(_prefKeySavedPassword, password);
        } else {
          await prefs.setBool(_prefKeyRememberPassword, false);
          await prefs.remove(_prefKeySavedEmail);
          await prefs.remove(_prefKeySavedPassword);
        }
      } catch (_) {
        // Non-fatal if persistence fails
      }

      TextInput.finishAutofillContext();

      // 6. Navigate to Admin Dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      }
    } catch (e) {
      final userMessage = _mapAuthError(e);

      // Audit failed login (fail-soft)
      SupabaseService.logAuthAudit(
        action: 'LOGIN_FAILED',
        email: email,
        details: userMessage,
      );

      if (mounted) {
        setState(() {
          _errorMessage = userMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Production Forgot Password Flow:
  /// Forgot Password -> Enter Email -> Send Reset Link -> Return to Login
  Future<void> _handleForgotPassword() async {
    final emailFromInput = _emailController.text.trim();
    final emailTextController = TextEditingController(text: emailFromInput);
    final formKey = GlobalKey<FormState>();

    final emailToReset = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Theme.of(context).colorScheme.primary, size: 26),
            const SizedBox(width: 8),
            const Text('Reset Admin Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your registered admin email address to receive a secure password reset link.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailTextController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'admin@siyasolar.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(emailTextController.text.trim());
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (emailToReset == null || emailToReset.isEmpty) return;

    try {
      await SupabaseService.resetPassword(emailToReset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $emailToReset. Check your inbox.'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapAuthError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Siya Solar Logo
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.solar_power_rounded,
                                size: 52,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Header: Title & Subtitle
                      Text(
                        'Siya Infotech Solar',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Admin Data Management Portal',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Error Alert Box
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Field 1: Email Address
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email, AutofillHints.username],
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'admin@siyasolar.com',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@') || !value.contains('.')) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Field 2: Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              enabled: !_isLoading,
                              onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Remember Password & Forgot Password Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _rememberPassword = !_rememberPassword;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: Checkbox(
                                        value: _rememberPassword,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        onChanged: _isLoading
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  _rememberPassword = val ?? false;
                                                });
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Remember Password',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _handleForgotPassword,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Action Button: Sign In to Admin Panel
                      FilledButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _loadingMessage,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Sign In to Admin Panel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
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
    );
  }
}
