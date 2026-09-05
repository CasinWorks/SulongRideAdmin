import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/trip_provider.dart';
import '../../components/primary_button.dart';

class PaymongoQrScreen extends ConsumerStatefulWidget {
  const PaymongoQrScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PaymongoQrScreen> createState() => _PaymongoQrScreenState();
}

class _PaymongoQrScreenState extends ConsumerState<PaymongoQrScreen> {
  bool _busy = false;

  String get _payload =>
      'paymongo://qrph?merchant=SulongRide&ref=SR-${widget.tripId.substring(0, 8)}';

  Future<void> _markPaid() async {
    setState(() => _busy = true);
    try {
      await ref.read(tripRepositoryProvider).markPaymongoPaid(widget.tripId);
      if (!mounted) return;
      context.go('/trip/${widget.tripId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripRealtimeProvider(widget.tripId)).asData?.value;
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=280x280&data=${Uri.encodeComponent(_payload)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text('PayMongo QR', style: AppTextStyles.headingSm),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Scan to pay', style: AppTextStyles.headingLg),
            const SizedBox(height: 8),
            Text(
              'Demo PayMongo QR Ph. Scan with GCash or Maya in production; '
              'for this mock, tap “I paid” after showing the QR.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Image.network(
                      qrUrl,
                      width: 220,
                      height: 220,
                      errorBuilder: (_, __, ___) => SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(
                          child: Text(
                            'QR\n${widget.tripId.substring(0, 8)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      trip != null
                          ? '₱${trip.fare.toStringAsFixed(2)}'
                          : 'Sulong Ride',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Ref SR-${widget.tripId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _busy ? 'Confirming…' : 'I paid (demo)',
              isLoading: _busy,
              onPressed: _busy ? null : _markPaid,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/trip/${widget.tripId}'),
              child: Text(
                'Pay later from trip',
                style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
