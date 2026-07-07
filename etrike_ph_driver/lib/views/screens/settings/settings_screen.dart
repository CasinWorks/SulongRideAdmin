import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_version.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/driver_local_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  String? _versionLabel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final push = await DriverLocalStore.pushNotifications();
    final version = await AppVersion.label();
    if (mounted) {
      setState(() {
        _pushNotifications = push;
        _versionLabel = version;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              children: [
                SwitchListTile(
                  title: Text('Message notifications', style: AppTextStyles.body),
                  subtitle: Text(
                    'Alert when a rider sends a chat message during an active trip.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  value: _pushNotifications,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) async {
                    await DriverLocalStore.setPushNotifications(v);
                    setState(() => _pushNotifications = v);
                  },
                ),
                const Divider(height: 32),
                ListTile(
                  leading: Icon(Icons.school_outlined, color: AppColors.accent.withValues(alpha: 0.85)),
                  title: Text('App tour', style: AppTextStyles.body),
                  subtitle: Text(
                    'Replay the welcome tutorial for approved drivers.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/welcome-approved?replay=1'),
                ),
                const Divider(height: 32),
                ListTile(
                  title: Text('App version', style: AppTextStyles.body),
                  subtitle: Text(
                    _versionLabel ?? '—',
                    style: AppTextStyles.bodySecondary,
                  ),
                  trailing: Icon(Icons.info_outline, color: AppColors.accent.withValues(alpha: 0.8)),
                ),
              ],
            ),
    );
  }
}
