import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_maintenance.dart';
import '../providers/auth_provider.dart';
import '../repositories/maintenance_repository.dart';

class MaintenanceController extends ChangeNotifier {
  MaintenanceController(this._ref) {
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => unawaited(refresh()));
  }

  final Ref _ref;
  Timer? _timer;

  AppMaintenanceStatus status = AppMaintenanceStatus.inactive();
  bool ready = false;

  bool get blocksApp => status.isBlocking;

  Future<void> refresh() async {
    try {
      status = await _ref.read(maintenanceRepositoryProvider).fetchStatus();
    } catch (_) {
      status = AppMaintenanceStatus.inactive();
    }
    ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(supabaseClientProvider));
});

final maintenanceControllerProvider = Provider<MaintenanceController>((ref) {
  final controller = MaintenanceController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

final appMaintenanceStatusProvider = Provider<AppMaintenanceStatus>((ref) {
  ref.watch(maintenanceControllerProvider);
  return ref.read(maintenanceControllerProvider).status;
});
