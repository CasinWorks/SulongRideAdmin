import '../models/driver_row.dart';
import 'driver_shift_config.dart';

extension DriverRowShift on DriverRow {
  DriverShiftConfig get shiftConfig => DriverShiftConfig.fromJson({
        'shift_days': shiftDays,
        'shift_start': shiftStart,
        'shift_end': shiftEnd,
        'station': station,
        'employment_type': employmentType,
      });
}
