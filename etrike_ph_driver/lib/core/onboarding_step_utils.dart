import '../models/onboarding_models.dart';

enum OnboardingStepStatus {
  notStarted,
  inProgress,
  complete,
  needsAttention,
}

class OnboardingStepSummary {
  const OnboardingStepSummary({
    required this.step,
    required this.label,
    required this.status,
    this.subtitle,
  });

  final int step;
  final String label;
  final OnboardingStepStatus status;
  final String? subtitle;
}

bool isPersonalInfoComplete(OnboardingBundle bundle) {
  final info = bundle.draft?.personalInfo ?? {};
  return (info['first_name']?.toString().trim().isNotEmpty ?? false) &&
      (info['last_name']?.toString().trim().isNotEmpty ?? false) &&
      (info['contact']?.toString().trim().isNotEmpty ?? false) &&
      (info['emergency_contact']?.toString().trim().isNotEmpty ?? false);
}

OnboardingStepStatus _documentStepStatus(OnboardingBundle bundle, int step) {
  final types = kDocumentsByWizardStep[step] ?? const <DocumentType>[];
  if (types.isEmpty) return OnboardingStepStatus.notStarted;

  if (types.any((t) => bundle.doc(t)?.status == DocumentStatus.rejected)) {
    return OnboardingStepStatus.needsAttention;
  }

  final uploaded = types.where((t) {
    final doc = bundle.doc(t);
    return doc?.fileUrl != null && doc!.status.isUploaded;
  }).length;

  if (uploaded == types.length) return OnboardingStepStatus.complete;
  if (uploaded > 0) return OnboardingStepStatus.inProgress;
  return OnboardingStepStatus.notStarted;
}

String? _documentStepSubtitle(OnboardingBundle bundle, int step) {
  final types = kDocumentsByWizardStep[step] ?? const <DocumentType>[];
  if (types.isEmpty) return null;
  final uploaded = types.where((t) {
    final doc = bundle.doc(t);
    return doc?.fileUrl != null && doc!.status.isUploaded;
  }).length;
  return '$uploaded/${types.length} documents uploaded';
}

List<OnboardingStepSummary> buildOnboardingStepSummaries({
  required OnboardingBundle bundle,
  bool trainingComplete = false,
}) {
  return List.generate(kDriverOnboardingStepLabels.length, (index) {
    final step = index + 1;
    final label = kDriverOnboardingStepLabels[index];

    if (step == 1) {
      final complete = isPersonalInfoComplete(bundle);
      return OnboardingStepSummary(
        step: step,
        label: label,
        status: complete
            ? OnboardingStepStatus.complete
            : OnboardingStepStatus.notStarted,
        subtitle: complete ? 'Saved — tap to edit' : 'Tap to enter details',
      );
    }

    if (step == 6) {
      return OnboardingStepSummary(
        step: step,
        label: label,
        status: trainingComplete
            ? OnboardingStepStatus.complete
            : OnboardingStepStatus.notStarted,
        subtitle: trainingComplete ? 'Training complete' : 'Tap to open training',
      );
    }

    if (step == 7) {
      final pct = bundle.checklistPercent;
      return OnboardingStepSummary(
        step: step,
        label: label,
        status: pct >= 100
            ? OnboardingStepStatus.complete
            : OnboardingStepStatus.inProgress,
        subtitle: pct >= 100 ? 'Ready to submit' : 'Checklist $pct% — finish uploads first',
      );
    }

    final status = _documentStepStatus(bundle, step);
    return OnboardingStepSummary(
      step: step,
      label: label,
      status: status,
      subtitle: _documentStepSubtitle(bundle, step),
    );
  });
}
