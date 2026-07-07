import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/keys.dart';
import '../../../core/rider_launch_route.dart';
import '../../../providers/auth_provider.dart';
import '../../components/custom_text_field.dart';
import '../../components/google_sign_in_button.dart';
import '../../components/primary_button.dart';

final _registerSubmittingProvider = StateProvider<bool>((ref) => false);
final _registerErrorProvider = StateProvider<String?>((ref) => null);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _formatRegisterError(Object error) {
    final message = error.toString();
    if (message.contains('row-level security') ||
        message.contains('42501') ||
        (message.contains('users') &&
            (message.contains('Unauthorized') || message.contains('violates')))) {
      return 'Supabase blocked creating your profile (RLS). '
          'In the Supabase SQL Editor, run supabase/fix_users_rls.sql, '
          'then try Register again.';
    }
    return message;
  }

  Future<void> _submit() async {
    ref.read(_registerErrorProvider.notifier).state = null;
    ref.read(_registerSubmittingProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
          );
      if (mounted) {
        final route = await resolveRiderLaunchRoute();
        if (mounted) context.go(route);
      }
    } catch (e) {
      ref.read(_registerErrorProvider.notifier).state = _formatRegisterError(e);
    } finally {
      ref.read(_registerSubmittingProvider.notifier).state = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    ref.read(_registerErrorProvider.notifier).state = null;
    ref.read(_registerSubmittingProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) {
        final route = await resolveRiderLaunchRoute();
        if (mounted) context.go(route);
      }
    } catch (e) {
      ref.read(_registerErrorProvider.notifier).state = _formatRegisterError(e);
    } finally {
      ref.read(_registerSubmittingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(_registerSubmittingProvider);
    final error = ref.watch(_registerErrorProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create account', style: AppTextStyles.headingLg),
              const SizedBox(height: 8),
              Text(
                'We will save your profile to Supabase `users`.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 24),
              if (googleOAuthConfigured) ...[
                GoogleSignInButton(
                  label: 'Sign up with Google',
                  loading: submitting,
                  onPressed: () => _signInWithGoogle(),
                ),
                const SizedBox(height: 20),
                const AuthDivider(label: 'or register with email'),
                const SizedBox(height: 20),
              ],
              if (error != null) ...[
                Text(error, style: AppTextStyles.body.copyWith(color: AppColors.error)),
                const SizedBox(height: 12),
              ],
              CustomTextField(controller: _name, label: 'Full name'),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Register',
                isLoading: submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/onboarding?replay=1'),
                child: Text(
                  'See how it works first',
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
