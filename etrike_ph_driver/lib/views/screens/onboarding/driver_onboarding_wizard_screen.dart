import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/driver_route_guard.dart';
import '../../../models/onboarding_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/training_provider.dart';
import '../../../repositories/onboarding_repository.dart';
import '../training/driver_training_screen.dart';
import '../../components/custom_text_field.dart';
import '../../components/onboarding_document_tile.dart';
import '../../components/primary_button.dart';

class DriverOnboardingWizardScreen extends ConsumerStatefulWidget {
  const DriverOnboardingWizardScreen({super.key, this.initialStep = 1});

  final int initialStep;

  @override
  ConsumerState<DriverOnboardingWizardScreen> createState() =>
      _DriverOnboardingWizardScreenState();
}

class _DriverOnboardingWizardScreenState
    extends ConsumerState<DriverOnboardingWizardScreen> {
  late int _step;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  OnboardingBundle _bundle = const OnboardingBundle();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _emergency = TextEditingController();
  final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(1, 7);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _contact.dispose();
    _email.dispose();
    _emergency.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await ref.read(onboardingRepositoryProvider).fetchBundle();
      final profile = await ref.read(authRepositoryProvider).fetchDriverProfile();
      if (!mounted) return;
      _bundle = bundle;
      _step = bundle.draft?.currentStep ?? _step;
      _hydratePersonal(bundle, profile?.fullName, profile?.email, profile?.phone);
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _hydratePersonal(
    OnboardingBundle bundle,
    String? fullName,
    String? email,
    String? phone,
  ) {
    final info = bundle.draft?.personalInfo ?? {};
    _firstName.text = info['first_name'] as String? ?? _splitName(fullName).$1;
    _lastName.text = info['last_name'] as String? ?? _splitName(fullName).$2;
    _contact.text = info['contact'] as String? ?? phone ?? '';
    _email.text = info['email'] as String? ?? email ?? '';
    _emergency.text = info['emergency_contact'] as String? ?? '';
    _address.text = info['address'] as String? ?? '';
  }

  (String, String) _splitName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return ('', '');
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  Future<void> _saveStep1() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      throw StateError('Enter your first and last name.');
    }
    if (_contact.text.trim().isEmpty) {
      throw StateError('Enter your mobile number.');
    }
    if (_emergency.text.trim().isEmpty) {
      throw StateError('Enter an emergency contact number.');
    }
    await _repo.savePersonalInfo(
      firstName: _firstName.text,
      lastName: _lastName.text,
      contact: _contact.text,
      email: _email.text,
      emergencyContact: _emergency.text,
      address: _address.text,
    );
    ref.invalidate(driverProfileProvider);
    ref.invalidate(onboardingBundleProvider);
  }

  Future<void> _next() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == 1) await _saveStep1();
      if (_step < 7) {
        await _repo.saveDraftStep(_step + 1);
        if (_step + 1 >= 5) {
          _bundle = await _repo.fetchBundle();
        }
        setState(() => _step++);
      } else {
        final training = await ref.read(trainingRepositoryProvider).fetchTraining();
        if (!(training?.isComplete ?? false)) {
          throw StateError(
            'Complete rider protocol training (step 6) before submitting your application.',
          );
        }
        _bundle = await _repo.fetchBundle();
        await _repo.submitApplication();
        ref.invalidate(onboardingBundleProvider);
        await ref.read(driverRouteGuardProvider).refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted! We will notify you when approved.'),
            ),
          );
          context.go('/onboarding');
        }
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    if (_step <= 1) {
      context.pop();
      return;
    }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          kDriverOnboardingStepLabels[_step - 1],
          style: AppTextStyles.headingSm,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : _back,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(current: _step, onStepTap: _goToStep),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.error)),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _step == 6
                  ? const SizedBox.shrink()
                  : PrimaryButton(
                      label: _step == 7 ? 'Submit for review' : 'Save & continue',
                      isLoading: _busy,
                      onPressed: _next,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToStep(int step) {
    if (_busy || step == _step) return;
    setState(() => _step = step.clamp(1, 7));
  }

  Widget _buildStep() => switch (_step) {
        1 => _personalStep(),
        6 => DriverTrainingScreen(
            embedded: true,
            onCompleted: () async {
              await _repo.saveDraftStep(7);
              if (mounted) setState(() => _step = 7);
            },
          ),
        7 => _reviewStep(),
        _ => _documentsStep(_step),
      };

  Widget _personalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell us about yourself. This must match your government IDs.',
          style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
        ),
        const SizedBox(height: 20),
        CustomTextField(controller: _firstName, label: 'First name'),
        const SizedBox(height: 14),
        CustomTextField(controller: _lastName, label: 'Last name'),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _contact,
          label: 'Mobile number',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _emergency,
          label: 'Emergency contact number',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _address,
          label: 'Home address (optional)',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _documentsStep(int step) {
    final types = kDocumentsByWizardStep[step] ?? const <DocumentType>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step == 3) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Company-owned e-trike', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  'OR/CR is not required — SulongRide assigns your unit. '
                  'Upload your PDL and LTFRB franchise/CPC if applicable.',
                  style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
                ),
                if (_bundle.assignedVehicle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Assigned unit: ${_bundle.assignedVehicle!.displayLabel}',
                    style: AppTextStyles.body.copyWith(color: AppColors.accent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Use Camera or Gallery for photos. Files are stored securely and reviewed by your operator in the admin portal.',
          style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        ...types.map((t) => OnboardingDocumentTile(
              docType: t,
              existing: _bundle.doc(t),
              onUploaded: _load,
            )),
      ],
    );
  }

  Widget _reviewStep() {
    final pct = computeChecklistPercent(_bundle.documents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.ecoCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Checklist: $pct%', style: AppTextStyles.headingSm),
              const SizedBox(height: 8),
              Text(
                pct >= 100
                    ? 'All required documents are uploaded. Submit when ready.'
                    : 'Upload missing documents before submitting.',
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...kRequiredDriverDocuments.map((type) {
          final doc = _bundle.doc(type);
          final ok = doc?.fileUrl != null && doc!.status.isUploaded;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              ok ? Icons.check_circle : Icons.warning_amber_outlined,
              color: ok ? AppColors.accent : AppColors.amber,
            ),
            title: Text(type.label),
            subtitle: doc?.fileName != null ? Text(doc!.fileName!) : null,
          );
        }),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.onStepTap});

  final int current;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: List.generate(kDriverOnboardingStepLabels.length, (i) {
          final step = i + 1;
          final active = step == current;
          final done = step < current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: active
                  ? AppColors.accent
                  : done
                      ? AppColors.forestLight
                      : AppColors.forestMedium,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onStepTap(step),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    kDriverOnboardingStepLabels[i],
                    style: AppTextStyles.label.copyWith(
                      color: active ? AppColors.forestDark : AppColors.ecoCream,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
