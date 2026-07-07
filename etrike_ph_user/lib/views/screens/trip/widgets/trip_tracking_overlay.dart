import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/trip_live_activity_service.dart';
import '../../../../core/constants/app_decorations.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../models/driver_model.dart';
import '../../../../models/message_model.dart';
import '../../../../models/trip_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../providers/trip_provider.dart';
import '../../../components/chat_composer.dart';
import '../../../components/eco/eco_animations.dart';
import '../../../components/eco/eco_drawer.dart';
import 'trip_dynamic_island_bar.dart';
import 'trip_status_animations.dart';

class TripTrackingOverlay extends ConsumerStatefulWidget {
  const TripTrackingOverlay({
    super.key,
    required this.trip,
    required this.driver,
    required this.etaLabel,
  });

  final TripModel trip;
  final DriverModel? driver;
  final String etaLabel;

  @override
  ConsumerState<TripTrackingOverlay> createState() => _TripTrackingOverlayState();
}

class _TripTrackingOverlayState extends ConsumerState<TripTrackingOverlay> {
  bool _showChat = false;
  bool _showSafety = false;
  bool _tripShared = false;
  final _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLiveActivity());
  }

  @override
  void didUpdateWidget(covariant TripTrackingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.status != widget.trip.status ||
        oldWidget.driver?.id != widget.driver?.id) {
      _syncLiveActivity();
    }
  }

  void _syncLiveActivity() {
    unawaited(
      TripLiveActivityService.syncFromTrip(widget.trip, driver: widget.driver),
    );
  }

  int _progressIndex() {
    return switch (widget.trip.status) {
      'accepted' => 1,
      'ongoing' => 2,
      _ => 0,
    };
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  _StatusCopy _statusCopy() {
    switch (widget.trip.status) {
      case 'accepted':
        final name = widget.driver?.fullName ?? 'Your driver';
        return _StatusCopy(
          title: 'Driver assigned',
          subtitle: '$name is on the way to your pickup',
          titleColor: AppColors.ecoGreenLight,
          phase: TripVisualPhase.assigned,
        );
      case 'ongoing':
        return _StatusCopy(
          title: 'En route',
          subtitle: 'Heading to ${widget.trip.dropoffAddress}',
          titleColor: AppColors.ecoGreenLight,
          phase: TripVisualPhase.enRoute,
        );
      default:
        return _StatusCopy(
          title: 'Finding your trike',
          subtitle: 'Matching you with the nearest electric driver',
          titleColor: AppColors.ecoGreenLight,
          phase: TripVisualPhase.searching,
        );
    }
  }

  String _etaLabel() => widget.etaLabel;

  Future<void> _cancelTrip() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.forestMedium,
        title: Text('Cancel ride?', style: AppTextStyles.headingSm),
        content: Text(
          'Free cancellation is active for this booking.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await TripLiveActivityService.end();
    try {
      await ref.read(tripRepositoryProvider).cancelTrip(widget.trip.id);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await ref.read(tripChatProvider(widget.trip.id).notifier).send(
            text: text,
            senderRole: 'rider',
          );
      _chatController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _openChat() {
    ref.read(tripChatProvider(widget.trip.id).notifier).setChatVisible(true);
    setState(() => _showChat = true);
  }

  void _closeChat() {
    ref.read(tripChatProvider(widget.trip.id).notifier).setChatVisible(false);
    setState(() => _showChat = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusCopy();
    final driver = widget.driver;
    final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final chatState = ref.watch(tripChatProvider(widget.trip.id));
    final messages = chatState.mergedMessages(uid ?? '');
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: topPad + 2,
          left: 0,
          right: 0,
          child: Center(
            child: TripDynamicIslandBar(
              title: status.title,
              etaLabel: _etaLabel(),
              phase: status.phase,
              progress: _progressIndex(),
            ),
          ),
        ),
        Positioned(
          top: topPad + 52,
          left: 28,
          right: 28,
          child: Center(
            child: TripStatusBanner(
              title: status.title,
              subtitle: status.subtitle,
              etaLabel: _etaLabel(),
              phase: status.phase,
              titleColor: status.titleColor,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: EcoSlideUp(
            child: Container(
              decoration: AppDecorations.ecoDrawer(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EcoDrawerHandle(),
                  TripProgressRail(status: widget.trip.status),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: driver != null
                        ? _DriverCard(
                            key: ValueKey(driver.id),
                            driver: driver,
                            messageCount: messages.length,
                            onCall: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Calling ${driver.fullName} at ${driver.phone ?? '—'}…',
                                  ),
                                ),
                              );
                            },
                            onChat: _openChat,
                          )
                        : widget.trip.status == 'requested'
                            ? const WaitingForDriverPanel(key: ValueKey('waiting'))
                            : Padding(
                                key: const ValueKey('loading'),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Driver details loading…',
                                  style: AppTextStyles.body,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.share_outlined,
                          label: _tripShared ? 'Tracking shared!' : 'Share ride',
                          highlight: _tripShared,
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: 'https://sulongride.app/trip/${widget.trip.id}'),
                            );
                            setState(() => _tripShared = true);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Secure tracker link copied to clipboard'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.shield_outlined,
                          label: 'Safety toolkit',
                          danger: true,
                          onTap: () => setState(() => _showSafety = true),
                        ),
                      ),
                    ],
                  ),
                  if (widget.trip.status != 'ongoing') ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _cancelTrip,
                      child: Text(
                        'Cancel eco-ride',
                        style: AppTextStyles.label.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_showChat && driver != null)
          Positioned.fill(
            child: _ChatOverlay(
              driverName: driver.fullName,
              messages: messages,
              currentUserId: uid,
              chatLoading: chatState.loading,
              chatError: chatState.error,
              controller: _chatController,
              onClose: _closeChat,
              onSend: _sendMessage,
              chatEnabled: tripChatIsOpen(widget.trip.status),
            ),
          ),
        if (_showSafety)
          Positioned.fill(
            child: _SafetyOverlay(
              onClose: () => setState(() => _showSafety = false),
              onShare: () {
                setState(() {
                  _tripShared = true;
                  _showSafety = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency contacts notified')),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _StatusCopy {
  const _StatusCopy({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.phase,
  });

  final String title;
  final String subtitle;
  final Color titleColor;
  final TripVisualPhase phase;
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    super.key,
    required this.driver,
    required this.messageCount,
    required this.onCall,
    required this.onChat,
  });

  final DriverModel driver;
  final int messageCount;
  final VoidCallback onCall;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.ecoCard,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.forestLight,
            child: Text(
              driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : 'D',
              style: AppTextStyles.headingSm.copyWith(color: AppColors.ecoGreenLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.fullName, style: AppTextStyles.headingSm),
                Text(
                  driver.trikeModel ?? 'Electric trike',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  (driver.trikePlateNumber ?? '—').toUpperCase(),
                  style: AppTextStyles.mono.copyWith(color: AppColors.ecoGreenLight),
                ),
              ],
            ),
          ),
          _CircleBtn(icon: Icons.phone_outlined, onTap: onCall),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _CircleBtn(icon: Icons.chat_bubble_outline, onTap: onChat),
              if (messageCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$messageCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forestMedium,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: AppColors.ecoGreenLight),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger
          ? const Color(0xFF4C0519).withValues(alpha: 0.4)
          : highlight
              ? AppColors.ecoGreen.withValues(alpha: 0.15)
              : AppColors.forestMedium.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: danger ? AppColors.rose : AppColors.ecoGreenLight),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: danger ? AppColors.rose : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatOverlay extends StatelessWidget {
  const _ChatOverlay({
    required this.driverName,
    required this.messages,
    required this.currentUserId,
    required this.chatLoading,
    required this.chatError,
    required this.controller,
    required this.onClose,
    required this.onSend,
    required this.chatEnabled,
  });

  final String driverName;
  final List<MessageModel> messages;
  final String? currentUserId;
  final bool chatLoading;
  final String? chatError;
  final TextEditingController controller;
  final VoidCallback onClose;
  final Future<void> Function(String) onSend;
  final bool chatEnabled;

  static const _presets = [
    'Malapit na ako!',
    'Sandali lang po.',
    'Salamat!',
    'Hihintayin ko kayo.',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: EcoSlideUp(
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.72,
            decoration: AppDecorations.ecoDrawer(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driverName, style: AppTextStyles.headingSm),
                          Text(
                            'EcoRide secure chat',
                            style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Divider(color: AppColors.forestLight),
                Expanded(
                  child: ChatMessageList(
                    messages: messages,
                    currentUserId: currentUserId,
                    isRiderPerspective: true,
                    loading: chatLoading,
                    error: chatError,
                  ),
                ),
                ChatComposer(
                  controller: controller,
                  enabled: chatEnabled,
                  onSend: onSend,
                  presets: _presets,
                  hintText: 'Mag-message sa driver…',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyOverlay extends StatelessWidget {
  const _SafetyOverlay({required this.onClose, required this.onShare});

  final VoidCallback onClose;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: EcoSlideUp(
          child: Container(
            width: double.infinity,
            decoration: AppDecorations.ecoDrawer(),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.rose),
                    const SizedBox(width: 8),
                    Text('EcoRide Safety Center', style: AppTextStyles.headingSm),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect to emergency lines or share live telemetry with guardians in one tap.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 16),
                _SafetyBtn(
                  title: 'Call Emergency Hotline (911)',
                  subtitle: 'Direct alert to Philippine National Police',
                  danger: true,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Simulating 911 call — GPS shared'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _SafetyBtn(
                  title: 'Auto share with family',
                  subtitle: 'Automated live tracker sharing',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyBtn extends StatelessWidget {
  const _SafetyBtn({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger
          ? const Color(0xFF4C0519).withValues(alpha: 0.4)
          : AppColors.forestMedium.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: danger ? AppColors.rose : AppColors.ecoCream,
                      ),
                    ),
                    Text(subtitle, style: AppTextStyles.bodySecondary.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              Icon(
                danger ? Icons.phone : Icons.share_outlined,
                color: danger ? AppColors.rose : AppColors.ecoGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
