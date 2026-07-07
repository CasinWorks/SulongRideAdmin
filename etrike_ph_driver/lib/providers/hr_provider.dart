import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_record.dart';
import '../models/driver_stats.dart';
import '../models/leave_request.dart';
import '../repositories/hr_repository.dart';
import 'auth_provider.dart';

final hrRepositoryProvider = Provider<HrRepository>(
  (ref) => HrRepository(ref.watch(supabaseClientProvider)),
);

final driverStatsProvider = FutureProvider<DriverStats>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) {
    return const DriverStats(
      completedTrips: 0,
      totalEarnings: 0,
      attendanceDays: 0,
      openShift: false,
    );
  }
  return ref.watch(hrRepositoryProvider).fetchDriverStats();
});

final openAttendanceProvider = FutureProvider<AttendanceRecord?>((ref) async {
  ref.watch(authUserIdProvider);
  return ref.watch(hrRepositoryProvider).fetchOpenAttendance();
});

final attendanceHistoryProvider = FutureProvider<List<AttendanceRecord>>((ref) async {
  ref.watch(authUserIdProvider);
  return ref.watch(hrRepositoryProvider).fetchAttendanceHistory();
});

final leaveRequestsProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  ref.watch(authUserIdProvider);
  return ref.watch(hrRepositoryProvider).fetchLeaveRequests();
});
