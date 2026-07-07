import '../models/driver_model.dart';
import '../models/onboarding_models.dart';
import '../models/training_models.dart';

/// Whether a driver may go Online and receive/accept trip requests.
class DriverTripEligibility {
  const DriverTripEligibility({
    required this.canReceiveTrips,
    this.primaryBlockReason,
    this.isApproved = false,
    this.documentsComplete = false,
    this.trainingComplete = false,
    this.hasAssignedVehicle = false,
  });

  final bool canReceiveTrips;
  final String? primaryBlockReason;
  final bool isApproved;
  final bool documentsComplete;
  final bool trainingComplete;
  final bool hasAssignedVehicle;
}

DriverTripEligibility evaluateDriverTripEligibility({
  DriverModel? profile,
  DriverTrainingRecord? training,
  OnboardingBundle? onboarding,
}) {
  if (profile == null) {
    return const DriverTripEligibility(
      canReceiveTrips: false,
      primaryBlockReason: 'Driver profile not found.',
    );
  }

  if (!profile.isApproved) {
    final reason = profile.approvalStatus == 'rejected'
        ? 'Your driver account was not approved. Contact the operator.'
        : 'Pending operator approval — you cannot receive bookings yet.';
    return DriverTripEligibility(
      canReceiveTrips: false,
      primaryBlockReason: reason,
      isApproved: false,
    );
  }

  final docsComplete = (onboarding?.checklistPercent ?? 0) >= 100;
  final trainingComplete = training?.isComplete ?? false;
  final hasVehicle = onboarding?.assignedVehicle != null;

  if (!docsComplete) {
    return DriverTripEligibility(
      canReceiveTrips: false,
      primaryBlockReason:
          'Complete all required onboarding documents before going Online.',
      isApproved: true,
      documentsComplete: false,
      trainingComplete: trainingComplete,
      hasAssignedVehicle: hasVehicle,
    );
  }

  if (!trainingComplete) {
    return DriverTripEligibility(
      canReceiveTrips: false,
      primaryBlockReason:
          'Complete rider protocol training before going Online.',
      isApproved: true,
      documentsComplete: true,
      trainingComplete: false,
      hasAssignedVehicle: hasVehicle,
    );
  }

  if (!hasVehicle) {
    return DriverTripEligibility(
      canReceiveTrips: false,
      primaryBlockReason:
          'No company e-trike assigned yet. Ask your operator to assign a fleet unit.',
      isApproved: true,
      documentsComplete: true,
      trainingComplete: true,
      hasAssignedVehicle: false,
    );
  }

  return const DriverTripEligibility(
    canReceiveTrips: true,
    isApproved: true,
    documentsComplete: true,
    trainingComplete: true,
    hasAssignedVehicle: true,
  );
}
