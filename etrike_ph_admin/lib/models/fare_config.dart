class FareConfig {
  const FareConfig({
    required this.id,
    required this.baseFare,
    required this.perKmRate,
    required this.minimumFare,
    required this.currency,
    required this.isActive,
  });

  final String id;
  final double baseFare;
  final double perKmRate;
  final double minimumFare;
  final String currency;
  final bool isActive;

  factory FareConfig.fromJson(Map<String, dynamic> json) {
    return FareConfig(
      id: json['id'] as String,
      baseFare: (json['base_fare'] as num?)?.toDouble() ?? 40,
      perKmRate: (json['per_km_rate'] as num?)?.toDouble() ?? 0,
      minimumFare: (json['minimum_fare'] as num?)?.toDouble() ?? 40,
      currency: json['currency'] as String? ?? 'PHP',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
