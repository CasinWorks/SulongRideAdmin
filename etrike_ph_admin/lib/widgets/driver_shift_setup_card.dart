import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/admin_tokens.dart';
import '../models/driver_row_shift.dart';
import '../models/driver_shift_config.dart';
import '../providers/admin_provider.dart';
import 'admin_ui.dart';

class DriverShiftSetupCard extends ConsumerStatefulWidget {
  const DriverShiftSetupCard({super.key, required this.driverId});

  final String driverId;

  @override
  ConsumerState<DriverShiftSetupCard> createState() => _DriverShiftSetupCardState();
}

class _DriverShiftSetupCardState extends ConsumerState<DriverShiftSetupCard> {
  DriverShiftConfig? _draft;
  var _saving = false;
  var _editing = false;
  final _customStation = TextEditingController();

  @override
  void dispose() {
    _customStation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one work day.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).updateDriverShift(
            driverId: widget.driverId,
            payload: draft.toUpdatePayload(),
          );
      ref.invalidate(driverRowProvider(widget.driverId));
      ref.invalidate(driverAdminProfileProvider(widget.driverId));
      ref.invalidate(driversDirectoryProvider);
      ref.invalidate(rosterForDateProvider);
      ref.invalidate(auditLogsProvider);
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift schedule saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyPreset(String key) {
    final preset = DriverShiftConfig.presets[key];
    if (preset == null || _draft == null) return;
    setState(() {
      _draft = _draft!.copyWith(
        days: preset.days,
        start: preset.start,
        end: preset.end,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverAsync = ref.watch(driverRowProvider(widget.driverId));

    return driverAsync.when(
      loading: () => const AdminPanelCard(
        title: 'Work schedule',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AdminPanelCard(title: 'Work schedule', child: Text('$e')),
      data: (driver) {
        if (driver == null) {
          return const AdminPanelCard(
            title: 'Work schedule',
            child: Text('Driver not found.'),
          );
        }

        _draft ??= driver.shiftConfig;
        final draft = _draft!;

        return AdminPanelCard(
          title: 'Work schedule',
          trailing: _editing
              ? TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))
              : TextButton(
                  onPressed: () {
                    _customStation.text = driver.station;
                    setState(() {
                      _editing = true;
                      _draft = driver.shiftConfig;
                    });
                  },
                  child: const Text('Edit'),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_editing) ...[
                _ReadRow('Days', draft.toDisplayString().split(' · ').first),
                _ReadRow('Hours', '${draft.formatTime(draft.start)} – ${draft.formatTime(draft.end)}'),
                _ReadRow('Station', draft.station),
                _ReadRow('Employment', draft.employmentLabel),
                const SizedBox(height: 8),
                Text(
                  driver.shiftSchedule,
                  style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
                ),
              ] else ...[
                Text('Quick presets', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DriverShiftConfig.presets.keys.map((key) {
                    return ActionChip(
                      label: Text(key, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _applyPreset(key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Work days', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = draft.days.contains(day);
                    return FilterChip(
                      label: Text(DriverShiftConfig.weekdayLabels[i]),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          final next = Set<int>.from(draft.days);
                          if (v) {
                            next.add(day);
                          } else {
                            next.remove(day);
                          }
                          _draft = draft.copyWith(days: next);
                        });
                      },
                      selectedColor: AdminTokens.accent.withValues(alpha: 0.2),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Shift start',
                        value: draft.start,
                        onPick: (t) => setState(() => _draft = draft.copyWith(start: t)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeField(
                        label: 'Shift end',
                        value: draft.end,
                        onPick: (t) => setState(() => _draft = draft.copyWith(end: t)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: DriverShiftConfig.presetStations.contains(draft.station)
                      ? draft.station
                      : '__other__',
                  decoration: const InputDecoration(
                    labelText: 'Station / depot',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ...DriverShiftConfig.presetStations.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                    const DropdownMenuItem(value: '__other__', child: Text('Other…')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    if (v == '__other__') {
                      setState(() => _draft = draft.copyWith(station: ''));
                    } else {
                      setState(() => _draft = draft.copyWith(station: v));
                    }
                  },
                ),
                if (!DriverShiftConfig.presetStations.contains(draft.station))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _customStation,
                      decoration: const InputDecoration(
                        labelText: 'Custom station name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _draft = draft.copyWith(station: v)),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: draft.employmentType,
                  decoration: const InputDecoration(
                    labelText: 'Employment type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'contractual', child: Text('Contractual')),
                    DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _draft = draft.copyWith(employmentType: v));
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _editing = false;
                                _draft = driver.shiftConfig;
                              }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save schedule'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AdminTokens.textSecondary, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    final fmt = MaterialLocalizations.of(context);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: value);
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(fmt.formatTimeOfDay(value)),
      ),
    );
  }
}
