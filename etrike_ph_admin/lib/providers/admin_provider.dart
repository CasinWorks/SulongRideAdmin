import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_log_row.dart';
import '../models/admin_models.dart';
import '../models/attendance_row.dart';
import '../models/driver_row.dart';
import '../models/fare_config.dart';
import '../models/leave_row.dart';
import '../models/roster_models.dart';
import '../models/onboarding_models.dart';
import '../repositories/admin_repository.dart';
import '../repositories/onboarding_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

final isOperatorProvider = FutureProvider<bool>((ref) async {
  return ref.watch(adminRepositoryProvider).isOperator();
});

final pendingDriversProvider = FutureProvider<List<DriverRow>>((ref) async {
  return ref.watch(adminRepositoryProvider).listDrivers(approvalStatus: 'pending');
});

final approvedDriversProvider = FutureProvider<List<DriverRow>>((ref) async {
  return ref.watch(adminRepositoryProvider).listDrivers(approvalStatus: 'approved');
});

final rejectedDriversProvider = FutureProvider<List<DriverRow>>((ref) async {
  return ref.watch(adminRepositoryProvider).listDrivers(approvalStatus: 'rejected');
});

final activeFareProvider = FutureProvider<FareConfig?>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchActiveFare();
});

final attendanceListProvider = FutureProvider<List<AttendanceRow>>((ref) async {
  return ref.watch(adminRepositoryProvider).listAttendance();
});

final pendingLeaveProvider = FutureProvider<List<LeaveRow>>((ref) async {
  return ref.watch(adminRepositoryProvider).listLeaveRequests(status: 'pending');
});

final fleetStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchFleetStats();
});

final fleetOverviewProvider = FutureProvider<FleetOverviewData>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchFleetOverview();
});

final driverAdminProfileProvider = FutureProvider.family<DriverProfile, String>((ref, id) async {
  return ref.watch(adminRepositoryProvider).fetchDriverProfile(id);
});

final driverRowProvider = FutureProvider.family<DriverRow?, String>((ref, id) async {
  return ref.watch(adminRepositoryProvider).fetchDriver(id);
});

final weeklyTripsByDriverProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchWeeklyTripsByDriver();
});

final rosterForDateProvider = FutureProvider.family<DayRosterSummary, DateTime>((ref, day) async {
  return ref.watch(adminRepositoryProvider).fetchRosterForDate(day);
});

final monthShiftCountsProvider =
    FutureProvider.family<Map<DateTime, int>, DateTime>((ref, month) async {
  return ref.watch(adminRepositoryProvider).fetchShiftCountsForMonth(month);
});

final driversDirectoryProvider = FutureProvider<List<DriverDirectoryEntry>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchDriversDirectory();
});

final driverScheduleProvider =
    FutureProvider.family<List<DriverScheduleDay>, (String, DateTime)>((ref, params) async {
  final (driverId, month) = params;
  return ref.watch(adminRepositoryProvider).fetchDriverSchedule(driverId, month);
});

final auditLogsProvider = FutureProvider<List<AuditLogRow>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchAuditLogs(limit: 150);
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(supabaseClientProvider)),
);

final availableVehiclesProvider = FutureProvider.family<List<VehicleRow>, String?>(
  (ref, driverId) async {
    return ref.watch(onboardingRepositoryProvider).listAvailableVehicles(forDriverId: driverId);
  },
);

final driverDocumentsProvider = FutureProvider.family<List<DriverDocumentRow>, String>(
  (ref, driverId) async {
    return ref.watch(onboardingRepositoryProvider).listDocuments(driverId);
  },
);

final driverPipelineProvider = FutureProvider.family<HiringPipelineState?, String>(
  (ref, driverId) async {
    return ref.watch(onboardingRepositoryProvider).fetchPipeline(driverId);
  },
);

final driverRegistrationDraftProvider = FutureProvider.family<RegistrationDraft?, String>(
  (ref, driverId) async {
    return ref.watch(onboardingRepositoryProvider).fetchDraft(driverId);
  },
);

final pendingDriversForRegistrationProvider = FutureProvider<List<DriverRow>>((ref) async {
  return ref.watch(adminRepositoryProvider).listDrivers(approvalStatus: 'pending');
});
