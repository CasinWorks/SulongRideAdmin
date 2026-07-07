import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/keys.dart';
import '../../../core/driver_route_guard.dart';
import '../../../core/remember_me_storage.dart';
import '../../../providers/auth_provider.dart';
import '../../components/custom_text_field.dart';
import '../../components/google_sign_in_button.dart';
import '../../components/primary_button.dart';

final _loginSubmittingProvider = StateProvider<bool>((ref) => false);
final _loginErrorProvider = StateProvider<String?>((ref) => null);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _hydrateRememberMe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(_loginSubmittingProvider.notifier).state = false;
      ref.read(_loginErrorProvider.notifier).state = null;
    });
  }

  Future<void> _hydrateRememberMe() async {
    try {
      final state = await RememberMeStorage.read();
      if (!mounted) return;
      setState(() {
        _rememberMe = state.enabled;
        _email.text = state.email;
        _password.text = state.password;
      });
    } catch (_) {
      // Best-effort; login must still work if secure storage fails.
    }
  }

  String _formatLoginError(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    final message = error.toString();
    if (message.contains('not registered as a driver')) {
      return 'This account is not registered as a driver. '
          'Register in this app, sign in again after Register (creates your driver profile), '
          'or run supabase/backfill_drivers_from_auth.sql in Supabase.';
    }
    if (message.contains('row-level security') ||
        message.contains('42501') ||
        (message.contains('drivers') &&
            (message.contains('Unauthorized') || message.contains('violates')))) {
      return 'Supabase blocked your driver profile (RLS). '
          'In the SQL Editor, run supabase/setup_test_driver.sql, then try again.';
    }
    if (message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('Network is unreachable')) {
      return 'Network error. Check your connection and try again.';
    }
    if (message.contains('not registered as a driver')) {
      return 'This Google account is not registered as a driver. '
          'Register in this app with email first, then you can use Google sign-in.';
    }
    if (message.contains('cancelled')) return 'Google sign-in was cancelled.';
    if (message.contains('not configured')) {
      return 'Google sign-in is not set up yet. Use email and password.';
    }
    if (message.contains('ID token')) {
      return 'Google sign-in failed. Check OAuth client IDs in keys.dart and Info.plist.';
    }
    return message;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted) return;
    ref.read(_loginErrorProvider.notifier).state = null;
    ref.read(_loginSubmittingProvider.notifier).state = true;
    try {
      if (_rememberMe) {
        await RememberMeStorage.write(
          enabled: true,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await RememberMeStorage.clear();
      }
      final repo = ref.read(authRepositoryProvider);
      await repo.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      ref.read(_loginSubmittingProvider.notifier).state = false;
      final route = await resolvePostAuthRoute(ref);
      if (!mounted) return;
      context.go(route);
    } catch (e) {
      if (!mounted) return;
      ref.read(_loginErrorProvider.notifier).state = _formatLoginError(e);
      ref.read(_loginSubmittingProvider.notifier).state = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    ref.read(_loginErrorProvider.notifier).state = null;
    ref.read(_loginSubmittingProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (_rememberMe) {
        await RememberMeStorage.write(
          enabled: true,
          email: _email.text,
          password: '',
        );
      }
      if (!mounted) return;
      ref.read(_loginSubmittingProvider.notifier).state = false;
      final route = await resolvePostAuthRoute(ref);
      if (!mounted) return;
      context.go(route);
    } catch (e) {
      if (!mounted) return;
      ref.read(_loginErrorProvider.notifier).state = _formatLoginError(e);
      ref.read(_loginSubmittingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(_loginSubmittingProvider);
    final error = ref.watch(_loginErrorProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Magandang araw',
                style: AppTextStyles.label.copyWith(color: AppColors.ecoGreenLight),
              ),
              const SizedBox(height: 4),
              Text('Driver sign in', style: AppTextStyles.headingLg),
              const SizedBox(height: 8),
              Text(
                'Use the email linked to your `drivers` profile.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 32),
              if (googleOAuthConfigured) ...[
                GoogleSignInButton(
                  loading: submitting,
                  onPressed: () => _signInWithGoogle(),
                ),
                const SizedBox(height: 20),
                const AuthDivider(),
                const SizedBox(height: 20),
              ],
              if (error != null) ...[
                Text(error, style: AppTextStyles.body.copyWith(color: AppColors.error)),
                const SizedBox(height: 12),
              ],
              CustomTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _password,
                label: 'Password',
                obscure: true,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: submitting
                        ? null
                        : (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: AppColors.ecoGreenLight,
                    checkColor: AppColors.background,
                    side: BorderSide(color: AppColors.forestLight.withValues(alpha: 0.8)),
                  ),
                  Text(
                    'Remember me',
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Sign in',
                isLoading: submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/register'),
                child: Text(
                  "Don't have an account? Register",
                  style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
