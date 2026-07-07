import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/eta_utils.dart';
import '../../../core/eco/eco_local_store.dart';
import '../../../core/eco/eco_models.dart';
import '../../../models/trip_model.dart';
import '../../../providers/trip_provider.dart';
import '../../components/eco/eco_animations.dart';
import '../../components/eco/eco_drawer.dart';
import '../../components/eco/eco_metric_tile.dart';
import '../../components/eco/eco_tab_switcher.dart';
import '../../components/eco/vehicle_option_card.dart';
import '../../components/primary_button.dart';

typedef BookRideCallback = void Function({
  required double fare,
  required String vehicleTypeId,
  String? promoCode,
});

enum LocationSearchTarget { pickup, dropoff }

class BookingBottomSheet extends ConsumerStatefulWidget {
  const BookingBottomSheet({
    super.key,
    required this.predictions,
    required this.searchBusy,
    required this.routeReady,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.distanceKm,
    this.routeDurationSeconds = 0,
    required this.bookingBusy,
    required this.onSearchChanged,
    required this.onPickPrediction,
    required this.onBook,
    this.searchTarget = LocationSearchTarget.dropoff,
    this.onSearchTargetChanged,
    this.onUseMyLocationForPickup,
    this.routeBusy = false,
    this.sheetNotice,
    this.onOpenLocationSettings,
    this.onRetryLocation,
    this.onPinOnMap,
    this.showPinOnMapOption = false,
  });

  final List<Map<String, dynamic>> predictions;
  final bool searchBusy;
  final bool routeReady;
  final String pickupLabel;
  final String dropoffLabel;
  final double distanceKm;
  final int routeDurationSeconds;
  final bool bookingBusy;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onPickPrediction;
  final BookRideCallback onBook;
  final LocationSearchTarget searchTarget;
  final ValueChanged<LocationSearchTarget>? onSearchTargetChanged;
  final VoidCallback? onUseMyLocationForPickup;
  final bool routeBusy;
  final String? sheetNotice;
  final VoidCallback? onOpenLocationSettings;
  final VoidCallback? onRetryLocation;
  final VoidCallback? onPinOnMap;
  final bool showPinOnMapOption;

  @override
  ConsumerState<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends ConsumerState<BookingBottomSheet> {
  bool _hubTab = false;
  String _vehicleTypeId = 'bike';
  final _promoController = TextEditingController();
  EcoPromoCode? _appliedPromo;
  String? _promoError;
  double _co2 = 4.8;
  int _rides = 12;
  double _wallet = 250;

  @override
  void initState() {
    super.initState();
    _loadEco();
  }

  Future<void> _loadEco() async {
    final co2 = await EcoLocalStore.co2Saved();
    final rides = await EcoLocalStore.greenRides();
    final wallet = await EcoLocalStore.walletBalance();
    final vehicleId = await EcoLocalStore.defaultVehicle();
    if (!mounted) return;
    setState(() {
      _co2 = co2;
      _rides = rides;
      _wallet = wallet;
      _vehicleTypeId = vehicleId.trim().isEmpty ? 'bike' : vehicleId.trim();
    });
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromo() {
    final found = EcoCatalog.findPromo(_promoController.text);
    setState(() {
      if (found != null) {
        _appliedPromo = found;
        _promoError = null;
      } else {
        _appliedPromo = null;
        _promoError = 'Invalid eco-promo code';
      }
    });
  }

  String _formatPeso(double amount) => '₱${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: widget.routeReady ? 0.52 : 0.36,
      minChildSize: 0.24,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return EcoSlideUp(
          child: Container(
            decoration: AppDecorations.ecoDrawer(),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                const EcoDrawerHandle(),
                EcoTabSwitcher(
                  leftLabel: 'Ride Commute',
                  rightLabel: 'Eco-Profile',
                  activeLeft: !_hubTab,
                  onChanged: (left) => setState(() => _hubTab = !left),
                ),
                const SizedBox(height: 16),
                if (_hubTab) ..._hubPanel(context) else ..._commutePanel(context),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _hubPanel(BuildContext context) {
    return [
      Row(
        children: [
          Expanded(
            child: EcoMetricTile(
              label: 'CO₂ saved',
              value: '${_co2.toStringAsFixed(1)} kg',
              icon: Icons.eco_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: EcoMetricTile(
              label: 'Green rides',
              value: '$_rides',
              icon: Icons.directions_bike_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: EcoMetricTile(
              label: 'EcoPay',
              value: _formatPeso(_wallet),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.ecoCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Carbon Hero', style: AppTextStyles.headingSm),
            const SizedBox(height: 6),
            Text(
              'Every electric trike ride avoids ~0.42 kg CO₂ vs a gasoline jeepney.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: 0.79,
                minHeight: 8,
                backgroundColor: AppColors.forestLight,
                color: AppColors.ecoGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text('79% to Emerald Rider badge', style: AppTextStyles.label),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _NavRow(
        icon: Icons.history,
        label: 'Trip history',
        onTap: () => context.push('/history'),
      ),
      _NavRow(
        icon: Icons.person_outline,
        label: 'Profile & wallet',
        onTap: () => context.push('/profile'),
      ),
      _NavRow(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () => context.push('/settings'),
      ),
    ];
  }

  List<Widget> _commutePanel(BuildContext context) {
    final fareConfig = ref.watch(fareConfigProvider).value ?? FareConfig.fallback;
    final vehiclesAsync = ref.watch(vehicleTypesProvider);
    final vehicles = vehiclesAsync.value ?? EcoCatalog.vehicles;
    final effectiveVehicleId = vehicles.any((v) => v.id == _vehicleTypeId)
        ? _vehicleTypeId
        : (vehicles.isNotEmpty ? vehicles.first.id : 'bike');
    final fare = applyEcoPromo(
      fareConfig.computeFare(widget.distanceKm),
      _appliedPromo,
    );
    final vehiclePriceLabel = _formatPeso(fare);
    final etaLabel = formatEtaMinutes(
      widget.routeDurationSeconds,
      fallback: formatEtaMinutes(
        estimateDurationSecondsFromKm(widget.distanceKm),
      ),
    );
    final distanceLabel = formatRouteDistanceKm(widget.distanceKm);

    return [
      Text(
        'Saan ka pupunta ngayon?',
        style: AppTextStyles.headingMd.copyWith(fontSize: 20),
      ),
      const SizedBox(height: 6),
      Text(
        widget.searchTarget == LocationSearchTarget.pickup
            ? 'Set where the driver should pick up — book for yourself or someone else.'
            : 'Search where you want to go.',
        style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
      ),
      const SizedBox(height: 12),
      TextField(
        onChanged: widget.onSearchChanged,
        style: AppTextStyles.body,
        cursorColor: AppColors.ecoGreen,
        decoration: InputDecoration(
          hintText: widget.searchTarget == LocationSearchTarget.pickup
              ? 'Search pickup in Carmona / Cavite'
              : 'Search destination in Carmona / Cavite',
          hintStyle: AppTextStyles.bodySecondary,
          prefixIcon: Icon(
            widget.searchTarget == LocationSearchTarget.pickup
                ? Icons.trip_origin
                : Icons.search,
            color: AppColors.ecoGreenLight,
          ),
          filled: true,
          fillColor: AppColors.forestMedium,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      if (widget.searchBusy || widget.routeBusy)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.ecoGreen,
            backgroundColor: AppColors.forestLight,
          ),
        ),
      if (widget.sheetNotice != null) ...[
        const SizedBox(height: 8),
        Text(
          widget.sheetNotice!,
          style: AppTextStyles.bodySecondary.copyWith(
            color: widget.predictions.isEmpty && widget.showPinOnMapOption
                ? AppColors.ecoGreenLight
                : AppColors.error,
          ),
        ),
      ],
      if (widget.showPinOnMapOption && widget.onPinOnMap != null) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onPinOnMap,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18, color: AppColors.ecoGreenLight),
            label: Text(
              widget.searchTarget == LocationSearchTarget.pickup
                  ? 'Pin pickup on map'
                  : 'Pin destination on map',
              style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
            ),
          ),
        ),
      ],
      ...widget.predictions.map(
        (p) => Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined, color: AppColors.ecoGreenLight),
            title: Text(p['description'] as String? ?? '', style: AppTextStyles.body),
            onTap: () => widget.onPickPrediction(p),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _LocationRow(
        label: 'Pickup',
        value: widget.pickupLabel,
        color: AppColors.pickupPin,
        active: widget.searchTarget == LocationSearchTarget.pickup,
        actionLabel: 'Change',
        onTap: () => widget.onSearchTargetChanged?.call(LocationSearchTarget.pickup),
      ),
      if (widget.searchTarget == LocationSearchTarget.pickup &&
          widget.onUseMyLocationForPickup != null) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onUseMyLocationForPickup,
            icon: const Icon(Icons.my_location, size: 18, color: AppColors.ecoGreenLight),
            label: Text(
              'Use my current location',
              style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
            ),
          ),
        ),
      ],
      if (widget.onPinOnMap != null &&
          !(widget.showPinOnMapOption && widget.predictions.isEmpty)) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onPinOnMap,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18, color: AppColors.ecoGreenLight),
            label: Text(
              widget.searchTarget == LocationSearchTarget.pickup
                  ? 'Pin pickup on map instead'
                  : 'Pin destination on map instead',
              style: AppTextStyles.body.copyWith(
                color: AppColors.ecoGreenLight,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
      if (widget.pickupLabel == 'Locating…' &&
          (widget.onRetryLocation != null || widget.onOpenLocationSettings != null)) ...[
        Wrap(
          spacing: 8,
          children: [
            if (widget.onRetryLocation != null)
              TextButton(onPressed: widget.onRetryLocation, child: const Text('Retry location')),
            if (widget.onOpenLocationSettings != null)
              TextButton(
                onPressed: widget.onOpenLocationSettings,
                child: const Text('Open Settings'),
              ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      _LocationRow(
        label: 'Drop-off',
        value: widget.dropoffLabel,
        color: AppColors.dropoffPin,
        active: widget.searchTarget == LocationSearchTarget.dropoff,
        actionLabel: widget.dropoffLabel == 'Choose a destination' ? 'Set' : 'Change',
        onTap: () => widget.onSearchTargetChanged?.call(LocationSearchTarget.dropoff),
      ),
      if (widget.pickupLabel == 'Locating…') ...[
        const SizedBox(height: 8),
        Text(
          'Getting your pickup location — distance and time update once GPS is ready.',
          style: AppTextStyles.bodySecondary.copyWith(
            fontSize: 11,
            color: AppColors.ecoGreenLight,
          ),
        ),
      ],
      if (widget.routeReady) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            _Chip(label: distanceLabel),
            const SizedBox(width: 8),
            _Chip(label: etaLabel),
            if (_appliedPromo != null) ...[
              const SizedBox(width: 8),
              _Chip(
                label: _appliedPromo!.code,
                highlight: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text('Choose your eco-ride', style: AppTextStyles.headingSm),
        const SizedBox(height: 8),
        ...vehicles.map(
          (v) => VehicleOptionCard(
            option: v,
            selected: v.id == effectiveVehicleId,
            priceLabel: vehiclePriceLabel,
            onTap: () async {
              setState(() => _vehicleTypeId = v.id);
              await EcoLocalStore.setDefaultVehicle(v.id);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoController,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Eco-promo code',
                  hintStyle: AppTextStyles.bodySecondary,
                  filled: true,
                  fillColor: AppColors.forestMedium,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _applyPromo,
              child: Text('Apply', style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight)),
            ),
          ],
        ),
        if (_promoError != null)
          Text(_promoError!, style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error)),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Total fare', style: AppTextStyles.headingSm),
            const Spacer(),
            Text(
              _formatPeso(fare),
              style: AppTextStyles.displayMetric.copyWith(fontSize: 22),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Confirm eco-ride',
          isLoading: widget.bookingBusy,
          onPressed: widget.routeReady
              ? () => widget.onBook(
                    fare: fare,
                    vehicleTypeId: effectiveVehicleId,
                    promoCode: _appliedPromo?.code,
                  )
              : null,
        ),
      ],
    ];
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.value,
    required this.color,
    this.active = false,
    this.actionLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final bool active;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.forestLight.withValues(alpha: 0.35) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.label),
                    Text(value, style: AppTextStyles.body),
                  ],
                ),
              ),
              if (actionLabel != null && onTap != null)
                Text(
                  actionLabel!,
                  style: AppTextStyles.label.copyWith(color: AppColors.ecoGreenLight),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.ecoGreen.withValues(alpha: 0.2)
            : AppColors.forestLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono.copyWith(
          color: highlight ? AppColors.ecoGreenLight : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.forestMedium,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.ecoGreenLight, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: AppTextStyles.body)),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
