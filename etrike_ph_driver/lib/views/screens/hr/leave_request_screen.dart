import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/hr_provider.dart';
import '../../components/custom_text_field.dart';
import '../../components/primary_button.dart';

class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  var _type = 'VL';
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  final _reason = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(hrRepositoryProvider).submitLeaveRequest(
            leaveType: _type,
            startDate: _start,
            endDate: _end,
            reason: _reason.text,
          );
      ref.invalidate(leaveRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted')),
        );
        _reason.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _statusColor(String status) => switch (status) {
        'approved' => AppColors.accent,
        'rejected' => AppColors.error,
        'cancelled' => AppColors.textSecondary,
        _ => AppColors.amber,
      };

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(leaveRequestsProvider);
    final fmt = DateFormat.yMMMd();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Leave requests', style: AppTextStyles.headingSm),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => ref.invalidate(leaveRequestsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Submit vacation leave (VL) or sick leave (SL). Your operator reviews requests in the admin portal.',
              style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.ecoCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'VL', label: Text('VL')),
                      ButtonSegment(value: 'SL', label: Text('SL')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start date'),
                    subtitle: Text(fmt.format(_start)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () => _pickDate(true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End date'),
                    subtitle: Text(fmt.format(_end)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () => _pickDate(false),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(controller: _reason, label: 'Reason'),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Submit request',
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Your requests', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (rows) {
                if (rows.isEmpty) {
                  return Text('No leave requests yet.', style: AppTextStyles.bodySecondary);
                }
                return Column(
                  children: rows.map((r) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecorations.ecoCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(r.leaveType, style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
                              const Spacer(),
                              Text(
                                r.status.toUpperCase(),
                                style: AppTextStyles.label.copyWith(
                                  color: _statusColor(r.status),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${fmt.format(r.startDate)} – ${fmt.format(r.endDate)} (${r.dayCount} day${r.dayCount == 1 ? '' : 's'})',
                            style: AppTextStyles.bodySecondary,
                          ),
                          if (r.reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(r.reason, style: AppTextStyles.body.copyWith(fontSize: 13)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
