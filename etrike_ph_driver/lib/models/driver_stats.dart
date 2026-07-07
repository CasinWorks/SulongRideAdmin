class DriverStats {
  const DriverStats({
    required this.completedTrips,
    required this.totalEarnings,
    required this.attendanceDays,
    required this.openShift,
    this.overallRating,
    this.ratingThisMonth,
    this.totalReviews = 0,
    this.complaintsLast7d = 0,
  });

  final int completedTrips;
  final double totalEarnings;
  final int attendanceDays;
  final bool openShift;
  final double? overallRating;
  final double? ratingThisMonth;
  final int totalReviews;
  final int complaintsLast7d;

  String get earningsLabel => '₱${totalEarnings.toStringAsFixed(0)}';
  String get ratingLabel =>
      overallRating != null ? '${overallRating!.toStringAsFixed(1)}★' : '—';
}

class DriverAchievement {
  const DriverAchievement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconName;
  final bool unlocked;

  static List<DriverAchievement> fromStats(DriverStats stats) {
    return [
      DriverAchievement(
        id: 'first_trip',
        title: 'First ride',
        subtitle: 'Complete your first trip',
        iconName: 'flag',
        unlocked: stats.completedTrips >= 1,
      ),
      DriverAchievement(
        id: 'ten_trips',
        title: 'On a roll',
        subtitle: '10 completed trips',
        iconName: 'local_taxi',
        unlocked: stats.completedTrips >= 10,
      ),
      DriverAchievement(
        id: 'fifty_trips',
        title: 'Road veteran',
        subtitle: '50 completed trips',
        iconName: 'emoji_events',
        unlocked: stats.completedTrips >= 50,
      ),
      DriverAchievement(
        id: 'first_shift',
        title: 'Clocked in',
        subtitle: 'First time in / time out',
        iconName: 'schedule',
        unlocked: stats.attendanceDays >= 1,
      ),
      DriverAchievement(
        id: 'week_streak',
        title: 'Consistent',
        subtitle: '5 days with attendance',
        iconName: 'calendar_month',
        unlocked: stats.attendanceDays >= 5,
      ),
      DriverAchievement(
        id: 'earnings_1k',
        title: 'Earner',
        subtitle: '₱1,000+ in completed fares',
        iconName: 'payments',
        unlocked: stats.totalEarnings >= 1000,
      ),
    ];
  }
}
