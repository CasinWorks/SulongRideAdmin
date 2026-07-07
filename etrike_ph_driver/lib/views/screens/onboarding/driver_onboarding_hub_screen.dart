import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/driver_route_guard.dart';
import '../../../models/driver_model.dart';
import '../../../models/onboarding_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../components/driver_ui.dart';
import '../../components/onboarding_steps_card.dart';
import '../../components/primary_button.dart';
import '../../../providers/training_provider.dart';

/// Landing screen for drivers pending operator approval.
class DriverOnboardingHubScreen extends ConsumerWidget {
  const DriverOnboardingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guard = ref.watch(driverRouteGuardProvider);
    final profile = guard.profile;
    final bundleAsync = ref.watch(onboardingBundleProvider);

    if (!guard.ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profile == null
          ? const Center(child: Text('No driver profile found'))
          : !guard.needsOnboarding
              ? Builder(
                  builder: (context) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!context.mounted) return;
                      final route = await resolvePostAuthRoute(ref);
                      if (!context.mounted) return;
                      context.go(route);
                    });
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  },
                )
              : bundleAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (e, _) => _ErrorBody(
                    message: '$e',
                    onRetry: () {
                      ref.invalidate(onboardingBundleProvider);
                      ref.invalidate(driverProfileProvider);
                      ref.read(driverRouteGuardProvider).refresh();
                    },
                  ),
                  data: (bundle) {
                    final trainingComplete =
                        ref.watch(driverTrainingProvider).valueOrNull?.isComplete ?? false;
                    return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () async {
                ref.invalidate(onboardingBundleProvider);
                ref.invalidate(driverProfileProvider);
                await ref.read(driverRouteGuardProvider).refresh();
              },
              child: CustomScrollView(
                slivers: [
                  SliverAppBar.large(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.textPrimary,
                    title: Text('Driver onboarding', style: AppTextStyles.headingSm),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusBanner(profile: profile, bundle: bundle),
                          const SizedBox(height: 16),
                          _ProgressCard(percent: bundle.checklistPercent),
                          const SizedBox(height: 16),
                          _FleetNoteCard(assignedVehicle: bundle.assignedVehicle),
                          const SizedBox(height: 16),
                          OnboardingStepsCard(
                            bundle: bundle,
                            trainingComplete: trainingComplete,
                            onStepTap: (step) =>
                                context.push('/onboarding/apply?step=$step'),
                          ),
                          const SizedBox(height: 16),
                          _DocumentChecklistCard(bundle: bundle),
                          const SizedBox(height: 16),
                          if (bundle.pipeline?.timeline.isNotEmpty ?? false)
                            _TimelineCard(entries: bundle.pipeline!.timeline),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: _primaryActionLabel(bundle),
                            onPressed: () {
                              final step = _resumeWizardStep(bundle);
                              context.push('/onboarding/apply?step=$step');
                            },
                          ),
                          const SizedBox(height: 12),
                          if (profile.approvalStatus == 'rejected')
                            Text(
                              'Your application was not approved. Update your documents and contact your operator.',
                              style: AppTextStyles.bodySecondary,
                            )
                          else if (_requirementsPendingMessage(bundle) != null)
                            Text(
                              _requirementsPendingMessage(bundle)!,
                              style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
                            )
                          else
                            Text(
                              'Complete all steps, then submit for review. '
                              'You cannot go online until an operator approves you.',
                              style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
                            ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () async {
                              await ref.read(authRepositoryProvider).signOut();
                              if (context.mounted) context.go('/login');
                            },
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
                  },
                ),
    );
  }
}

String _primaryActionLabel(OnboardingBundle bundle) {
  if (_hasRejectedDocuments(bundle)) return 'Upload required documents';
  if (bundle.checklistPercent >= 100) return 'Review & submit';
  return 'Continue application';
}

int _resumeWizardStep(OnboardingBundle bundle) {
  for (final entry in kDocumentsByWizardStep.entries) {
    for (final type in entry.value) {
      final doc = bundle.doc(type);
      final needsUpload = doc == null ||
          doc.fileUrl == null ||
          doc.status == DocumentStatus.rejected;
      if (needsUpload) return entry.key;
    }
  }
  return bundle.draft?.currentStep ?? 1;
}

bool _hasRejectedDocuments(OnboardingBundle bundle) {
  return kRequiredDriverDocuments.any(
    (type) => bundle.doc(type)?.status == DocumentStatus.rejected,
  );
}

String? _requirementsPendingMessage(OnboardingBundle bundle) {
  final entry = bundle.pipeline?.timeline
      .where((e) => e.action == 'requirements_pending')
      .firstOrNull;
  if (entry == null) return null;
  return 'Your operator requested updated documents before you can receive bookings. '
      '${entry.summary}';
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.profile, required this.bundle});

  final DriverModel profile;
  final OnboardingBundle bundle;

  @override
  Widget build(BuildContext context) {
    final stage = bundle.pipeline?.stage ?? HiringStage.application;
    final requirementsNote = _requirementsPendingMessage(bundle);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard.copyWith(
        border: Border.all(
          color: requirementsNote != null
              ? AppColors.amber.withValues(alpha: 0.65)
              : AppColors.amber.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(profile.fullName, style: AppTextStyles.headingSm),
              ),
              ApprovalStatusChip(status: profile.approvalStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(profile.email, style: AppTextStyles.bodySecondary),
          if (requirementsNote != null) ...[
            const SizedBox(height: 12),
            Text(
              requirementsNote,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Stage: ${stage.label}',
            style: AppTextStyles.body.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.ecoCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Document checklist', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 6,
                  color: AppColors.accent,
                  backgroundColor: AppColors.forestLight.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$percent%', style: AppTextStyles.headingLg),
                    Text(
                      'Required documents uploaded',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FleetNoteCard extends StatelessWidget {
  const _FleetNoteCard({required this.assignedVehicle});

  final AssignedVehicle? assignedVehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.electric_moped_rounded, color: AppColors.accent.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Company e-trike',
                  style: AppTextStyles.headingSm.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'SulongRide provides your e-trike. You do not need to upload OR/CR (vehicle registration). '
            'Your operator assigns a fleet unit when you are approved.',
            style: AppTextStyles.bodySecondary.copyWith(height: 1.45),
          ),
          if (assignedVehicle != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Assigned unit: ${assignedVehicle!.displayLabel}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentChecklistCard extends StatelessWidget {
  const _DocumentChecklistCard({required this.bundle});

  final OnboardingBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Document checklist', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Quick view of each required file. Open the matching step above to upload or remove.',
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          ...kRequiredDriverDocuments.map((type) {
            final doc = bundle.doc(type);
            final uploaded = doc?.fileUrl != null && doc!.status.isUploaded;
            final rejected = doc?.status == DocumentStatus.rejected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    rejected
                        ? Icons.error_outline
                        : uploaded
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                    color: rejected
                        ? AppColors.error
                        : uploaded
                            ? AppColors.accent
                            : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(type.label, style: AppTextStyles.body)),
                  if (doc?.status == DocumentStatus.verified)
                    Text('Verified', style: AppTextStyles.label.copyWith(color: AppColors.accent)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entries});

  final List<OnboardingTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · h:mm a');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent activity', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          ...entries.take(5).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.summary, style: AppTextStyles.body),
                            Text(
                              fmt.format(e.at.toLocal()),
                              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
