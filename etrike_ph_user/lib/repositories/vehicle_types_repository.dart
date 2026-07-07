import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/eco/eco_models.dart';

class VehicleTypesRepository {
  VehicleTypesRepository(this._client);

  final SupabaseClient _client;

  Future<List<EcoVehicleOption>> listActiveVehicleTypes() async {
    final rows = await _client
        .from('vehicle_types')
        .select('id, name, description, icon, eta_minutes, sort_order')
        .order('sort_order', ascending: true)
        .order('name', ascending: true)
        .timeout(const Duration(seconds: 8));

    final list = (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (r) => EcoVehicleOption(
            id: (r['id'] as String?)?.trim() ?? '',
            name: (r['name'] as String?)?.trim() ?? '',
            description: (r['description'] as String?)?.trim() ?? '',
            basePrice: 0,
            pricePerKm: 0,
            icon: (r['icon'] as String?)?.trim().isNotEmpty == true
                ? (r['icon'] as String).trim()
                : '🛺',
            etaMinutes: (r['eta_minutes'] as int?) ?? 3,
          ),
        )
        .where((v) => v.id.isNotEmpty && v.name.isNotEmpty)
        .toList();

    // If table is empty/misconfigured, keep the app usable.
    if (list.isEmpty) return EcoCatalog.vehicles;

    // Use the static catalog for price/marketing fields (MVP), but keep admin-managed enable/disable/order.
    final staticById = {for (final v in EcoCatalog.vehicles) v.id: v};
    return list.map((v) {
      final fallback = staticById[v.id];
      if (fallback == null) return v;
      return EcoVehicleOption(
        id: v.id,
        name: v.name,
        description: v.description.isNotEmpty ? v.description : fallback.description,
        basePrice: fallback.basePrice,
        pricePerKm: fallback.pricePerKm,
        icon: v.icon,
        etaMinutes: v.etaMinutes,
      );
    }).toList();
  }
}

