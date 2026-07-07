import '../models/driver_stats.dart';
import '../models/trip_model.dart';

class DailyTripMetric {
  const DailyTripMetric({
    required this.date,
    required this.tripCount,
    required this.earnings,
  });

  final DateTime date;
  final int tripCount;
  final double earnings;
}

class DriverPerformanceSnapshot {
  const DriverPerformanceSnapshot({
    required this.stats,
    required this.last7Days,
    required this.starCounts,
    required this.ratedTrips,
    required this.unratedTrips,
  });

  final DriverStats stats;
  final List<DailyTripMetric> last7Days;
  final Map<int, int> starCounts;
  final int ratedTrips;
  final int unratedTrips;

  int get maxTripsPerDay =>
      last7Days.isEmpty ? 1 : last7Days.map((d) => d.tripCount).reduce((a, b) => a > b ? a : b).clamp(1, 999);

  double get maxEarningsPerDay => last7Days.isEmpty
      ? 1
      : last7Days.map((d) => d.earnings).reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);

  int get maxStarCount {
    if (starCounts.isEmpty) return 1;
    return starCounts.values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
  }
}

DateTime _tripDay(TripModel trip) {
  final raw = trip.completedAt ?? trip.createdAt;
  return DateTime(raw.year, raw.month, raw.day);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DriverPerformanceSnapshot buildPerformanceSnapshot({
  required DriverStats stats,
  required List<TripModel> trips,
}) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));

  final last7 = List.generate(7, (i) {
    final day = start.add(Duration(days: i));
    var count = 0;
    var earnings = 0.0;
    for (final t in trips) {
      if (!_isSameDay(_tripDay(t), day)) continue;
      count++;
      earnings += t.fare;
    }
    return DailyTripMetric(date: day, tripCount: count, earnings: earnings);
  });

  final stars = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
  var rated = 0;
  for (final t in trips) {
    final r = t.rating;
    if (r == null || r < 1 || r > 5) continue;
    rated++;
    stars[r] = (stars[r] ?? 0) + 1;
  }

  return DriverPerformanceSnapshot(
    stats: stats,
    last7Days: last7,
    starCounts: stars,
    ratedTrips: rated,
    unratedTrips: trips.length - rated,
  );
}
