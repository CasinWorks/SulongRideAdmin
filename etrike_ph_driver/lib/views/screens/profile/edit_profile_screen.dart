import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../components/custom_text_field.dart';
import '../../components/primary_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final driver = await ref.read(driverProfileProvider.future);
    if (driver == null || !mounted) return;
    _name.text = driver.fullName;
    _phone.text = driver.phone ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateDriverProfile(
            fullName: _name.text,
            phone: _phone.text,
          );
      ref.invalidate(driverProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(onboardingBundleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit profile', style: AppTextStyles.headingSm),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bundleAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (bundle) {
                final unit = bundle.assignedVehicle;
                final profile = ref.watch(driverProfileProvider).asData?.value;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.ecoCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Company e-trike', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
                      const SizedBox(height: 8),
                      if (unit != null)
                        Text(
                          'Unit ${unit.displayLabel}',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        )
                      else if (profile?.trikePlateNumber != null)
                        Text(
                          'Plate ${profile!.trikePlateNumber}',
                          style: AppTextStyles.body,
                        )
                      else
                        Text(
                          'Not assigned yet — your operator will assign a fleet unit.',
                          style: AppTextStyles.bodySecondary,
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Plate and unit are managed by SulongRide. You cannot edit them here.',
                        style: AppTextStyles.bodySecondary.copyWith(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            CustomTextField(controller: _name, label: 'Full name'),
            const SizedBox(height: 16),
            CustomTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Save changes', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
