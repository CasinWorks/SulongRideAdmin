import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_version.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/eco/eco_models.dart';
import '../../../core/eco/eco_local_store.dart';
import '../../../providers/trip_provider.dart';
import '../../components/eco/eco_animations.dart';
import '../../components/eco/eco_toggle.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pin = false;
  bool _push = true;
  bool _gps = true;
  String _vehicle = 'bike';
  String? _versionLabel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await EcoLocalStore.securityPinEnabled();
    final push = await EcoLocalStore.pushNotifications();
    final gps = await EcoLocalStore.highAccuracyGps();
    final vehicle = await EcoLocalStore.defaultVehicle();
    final version = await AppVersion.label();
    if (mounted) {
      setState(() {
        _pin = pin;
        _push = push;
        _gps = gps;
        _vehicle = vehicle;
        _versionLabel = version;
        _loading = false;
      });
    }
  }

  Future<void> _reset() async {
    await EcoLocalStore.resetAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App cache reset')),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleOptions = ref.watch(vehicleTypesProvider).value ?? EcoCatalog.vehicles;
    final effectiveSelected = vehicleOptions.any((v) => v.id == _vehicle)
        ? _vehicle
        : (vehicleOptions.isNotEmpty ? vehicleOptions.first.id : 'bike');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: Text('Settings', style: AppTextStyles.headingSm),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.ecoGreen))
          : EcoFadeIn(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Preferences', style: AppTextStyles.headingSm),
                  const SizedBox(height: 12),
                  _SettingTile(
                    title: 'Pre-boarding security PIN',
                    subtitle: 'Require PIN before starting a ride',
                    trailing: EcoToggle(
                      value: _pin,
                      onChanged: (v) async {
                        setState(() => _pin = v);
                        await EcoLocalStore.setSecurityPinEnabled(v);
                      },
                    ),
                  ),
                  _SettingTile(
                    title: 'Push notifications',
                    subtitle: 'Trip updates and driver messages',
                    trailing: EcoToggle(
                      value: _push,
                      onChanged: (v) async {
                        setState(() => _push = v);
                        await EcoLocalStore.setPushNotifications(v);
                      },
                    ),
                  ),
                  _SettingTile(
                    title: 'High-accuracy GPS',
                    subtitle: 'Better pickup pin placement',
                    trailing: EcoToggle(
                      value: _gps,
                      onChanged: (v) async {
                        setState(() => _gps = v);
                        await EcoLocalStore.setHighAccuracyGps(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Default vehicle', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: AppDecorations.ecoInput,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: effectiveSelected,
                        isExpanded: true,
                        dropdownColor: AppColors.forestMedium,
                        style: AppTextStyles.body,
                        items: vehicleOptions
                            .map(
                              (v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _vehicle = v);
                          await EcoLocalStore.setDefaultVehicle(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Help', style: AppTextStyles.headingSm),
                  const SizedBox(height: 12),
                  _SettingTile(
                    title: 'App tutorial',
                    subtitle: 'Replay the full-screen walkthrough',
                    trailing: IconButton(
                      icon: const Icon(Icons.school_outlined, color: AppColors.ecoGreenLight),
                      onPressed: () => context.push('/onboarding?replay=1'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('About', style: AppTextStyles.headingSm),
                  const SizedBox(height: 12),
                  _SettingTile(
                    title: 'App version',
                    subtitle: _versionLabel ?? '—',
                    trailing: const Icon(
                      Icons.info_outline,
                      color: AppColors.ecoGreenLight,
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: const BorderSide(color: AppColors.rose),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reset app cache'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.ecoCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
