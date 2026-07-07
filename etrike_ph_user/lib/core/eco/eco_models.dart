class EcoVehicleOption {
  const EcoVehicleOption({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.pricePerKm,
    required this.icon,
    required this.etaMinutes,
  });

  /// Stable identifier, stored in settings and synced from Supabase `vehicle_types`.
  /// Example: `bike`, `economy`, `premium`.
  final String id;
  final String name;
  final String description;
  final double basePrice;
  final double pricePerKm;
  final String icon;
  final int etaMinutes;

  double priceForKm(double distanceKm, {EcoPromoCode? promo}) {
    return applyEcoPromo(basePrice + distanceKm * pricePerKm, promo);
  }
}

double applyEcoPromo(double fare, EcoPromoCode? promo) {
  if (promo == null) return fare;
  var raw = fare;
  if (promo.type == EcoPromoType.fixed) {
    raw = (raw - promo.discount).clamp(10, double.infinity);
  } else {
    final discount = (raw * promo.discount / 100).clamp(0, 60);
    raw = (raw - discount).clamp(10, double.infinity);
  }
  return double.parse(raw.toStringAsFixed(2));
}

enum EcoPromoType { percent, fixed }

class EcoPromoCode {
  const EcoPromoCode({
    required this.code,
    required this.discount,
    required this.type,
    required this.description,
  });

  final String code;
  final double discount;
  final EcoPromoType type;
  final String description;
}

abstract final class EcoCatalog {
  static const vehicles = <EcoVehicleOption>[
    EcoVehicleOption(
      id: 'bike',
      name: 'EcoTrike Commuter',
      description: 'Standard electric tricycle with comfortable seating',
      basePrice: 20,
      pricePerKm: 5,
      icon: '🛺',
      etaMinutes: 2,
    ),
    EcoVehicleOption(
      id: 'economy',
      name: 'EcoTrike Solo',
      description: 'Agile, single-passenger electric micro-trike',
      basePrice: 15,
      pricePerKm: 4,
      icon: '🛺',
      etaMinutes: 3,
    ),
    EcoVehicleOption(
      id: 'premium',
      name: 'EcoTrike Premium',
      description: 'Deluxe tricycle with cushion seats and solar canopy',
      basePrice: 40,
      pricePerKm: 10,
      icon: '🛺⚡',
      etaMinutes: 4,
    ),
    EcoVehicleOption(
      id: 'xl',
      name: 'EcoTrike Sidecar XL',
      description: 'Large capacity electric sidecar for family or luggage',
      basePrice: 35,
      pricePerKm: 9,
      icon: '🛺',
      etaMinutes: 5,
    ),
    EcoVehicleOption(
      id: 'taxi',
      name: 'EcoRickshaw Express',
      description: 'Multi-seater covered electric passenger shuttle',
      basePrice: 25,
      pricePerKm: 7.5,
      icon: '🛺⚡',
      etaMinutes: 4,
    ),
  ];

  static const promos = <EcoPromoCode>[
    EcoPromoCode(
      code: 'GO_GREEN',
      discount: 15,
      type: EcoPromoType.fixed,
      description: 'Flat ₱15.00 off eco-ride',
    ),
    EcoPromoCode(
      code: 'SWAP_CO2',
      discount: 20,
      type: EcoPromoType.percent,
      description: '20% off up to ₱60.00',
    ),
    EcoPromoCode(
      code: 'WELCOME_ECO',
      discount: 50,
      type: EcoPromoType.percent,
      description: '50% off first eco-commute',
    ),
  ];

  static EcoPromoCode? findPromo(String input) {
    final code = input.trim().toUpperCase();
    for (final p in promos) {
      if (p.code == code) return p;
    }
    return null;
  }

  static EcoVehicleOption vehicle(String id) =>
      vehicles.firstWhere((v) => v.id == id);
}
