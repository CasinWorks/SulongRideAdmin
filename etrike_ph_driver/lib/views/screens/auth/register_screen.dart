import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/driver_local_store.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../components/custom_text_field.dart';
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
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
    _phone = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _formatRegisterError(Object error) {
    final message = error.toString();
    if (message.contains('row-level security') ||
        message.contains('42501') ||
        (message.contains('drivers') &&
            (message.contains('Unauthorized') || message.contains('violates')))) {
      return 'Supabase blocked creating your driver profile (RLS). '
          'In the Supabase SQL Editor, run supabase/setup_test_driver.sql '
          '(drivers_insert_own policy), then try Register again.';
    }
    return message;
  }

  Future<void> _submit() async {
    ref.read(_registerErrorProvider.notifier).state = null;
    ref.read(_registerSubmittingProvider.notifier).state = true;
    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.signUp(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );
      if (!mounted) return;
      ref.read(_registerSubmittingProvider.notifier).state = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check your email to confirm, OR disable Confirm email in '
            'Supabase → Authentication → Providers → Email for MVP testing.',
          ),
          duration: Duration(seconds: 8),
        ),
      );
      if (response.session != null) {
        await ref.read(onboardingRepositoryProvider).fetchBundle();
        await DriverLocalStore.setOnboardingComplete(false);
        if (!mounted) return;
        context.go('/welcome');
      } else {
        context.go('/login');
      }
    } catch (e) {
      if (!mounted) return;
      ref.read(_registerErrorProvider.notifier).state = _formatRegisterError(e);
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
              Text('Driver registration', style: AppTextStyles.headingLg),
              const SizedBox(height: 8),
              Text(
                'Create your account to start onboarding. SulongRide assigns your company e-trike — you do not enter a plate number here.',
                style: AppTextStyles.bodySecondary.copyWith(height: 1.45),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phone,
                label: 'Mobile number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Register',
                isLoading: submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
