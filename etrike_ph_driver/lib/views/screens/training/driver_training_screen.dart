import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/driver_route_guard.dart';
import '../../../models/training_models.dart';
import '../../../providers/training_provider.dart';
import '../../../repositories/training_repository.dart';
import '../../components/primary_button.dart';

/// Online rider protocol training + quiz. Onsite drivers see scheduling notice.
class DriverTrainingScreen extends ConsumerStatefulWidget {
  const DriverTrainingScreen({
    super.key,
    this.embedded = false,
    this.onCompleted,
  });

  /// When true, hides app bar back navigation (wizard step).
  final bool embedded;

  final VoidCallback? onCompleted;

  @override
  ConsumerState<DriverTrainingScreen> createState() => _DriverTrainingScreenState();
}

class _DriverTrainingScreenState extends ConsumerState<DriverTrainingScreen> {
  final _modulePage = PageController();
  var _moduleIndex = 0;
  var _showQuiz = false;
  var _busy = false;
  String? _error;
  final _answers = <String, int>{};

  TrainingRepository get _repo => ref.read(trainingRepositoryProvider);

  Future<void> _startOnline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.markTrainingStarted();
      ref.invalidate(driverTrainingProvider);
      if (mounted) setState(() => _showQuiz = false);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitQuiz() async {
    if (_answers.length < kTrainingQuizQuestions.length) {
      setState(() => _error = 'Answer all ${kTrainingQuizQuestions.length} questions.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.submitOnlineQuiz(_answers);
      ref.invalidate(driverTrainingProvider);
      ref.read(driverRouteGuardProvider).refresh();
      if (!mounted) return;
      widget.onCompleted?.call();
      if (!widget.embedded) context.go('/home');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _modulePage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trainingAsync = ref.watch(driverTrainingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Rider protocol training'),
            ),
      body: trainingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('$e')),
        data: (record) {
          if (record?.isComplete ?? false) {
            return _CompletedBody(
              record: record!,
              embedded: widget.embedded,
              onContinue: widget.onCompleted,
            );
          }
          if (record?.mode == TrainingMode.onsite) {
            return _OnsiteBody(record: record);
          }
          if (_showQuiz) {
            return _QuizBody(
              answers: _answers,
              error: _error,
              busy: _busy,
              onSelect: (qid, idx) => setState(() => _answers[qid] = idx),
              onSubmit: _submitQuiz,
              onBack: () => setState(() => _showQuiz = false),
            );
          }
          return _ModulesBody(
            modulePage: _modulePage,
            moduleIndex: _moduleIndex,
            error: _error,
            busy: _busy,
            onModuleChanged: (i) => setState(() => _moduleIndex = i),
            onStart: _startOnline,
            onTakeQuiz: () async {
              await _startOnline();
              if (mounted) setState(() => _showQuiz = true);
            },
          );
        },
      ),
    );
  }
}

class _ModulesBody extends StatelessWidget {
  const _ModulesBody({
    required this.modulePage,
    required this.moduleIndex,
    required this.error,
    required this.busy,
    required this.onModuleChanged,
    required this.onStart,
    required this.onTakeQuiz,
  });

  final PageController modulePage;
  final int moduleIndex;
  final String? error;
  final bool busy;
  final ValueChanged<int> onModuleChanged;
  final Future<void> Function() onStart;
  final VoidCallback onTakeQuiz;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: modulePage,
              itemCount: kTrainingProtocolModules.length,
              onPageChanged: onModuleChanged,
              itemBuilder: (_, i) {
                final m = kTrainingProtocolModules[i];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Module ${i + 1} of ${kTrainingProtocolModules.length}',
                          style: AppTextStyles.bodySecondary),
                      const SizedBox(height: 12),
                      Text(m.title, style: AppTextStyles.headingLg),
                      const SizedBox(height: 16),
                      Text(m.body, style: AppTextStyles.bodySecondary.copyWith(height: 1.5)),
                    ],
                  ),
                );
              },
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(error!, style: AppTextStyles.body.copyWith(color: AppColors.error)),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(
              label: moduleIndex == kTrainingProtocolModules.length - 1
                  ? 'Take quiz ($kTrainingPassScore% to pass)'
                  : 'Next module',
              isLoading: busy,
              onPressed: () {
                if (moduleIndex < kTrainingProtocolModules.length - 1) {
                  modulePage.nextPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                  );
                } else {
                  onTakeQuiz();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({
    required this.answers,
    required this.error,
    required this.busy,
    required this.onSelect,
    required this.onSubmit,
    required this.onBack,
  });

  final Map<String, int> answers;
  final String? error;
  final bool busy;
  final void Function(String qid, int idx) onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onBack, child: const Text('← Review modules')),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Protocol quiz', style: AppTextStyles.headingSm),
                const SizedBox(height: 8),
                Text(
                  'Answer all questions. You need $kTrainingPassScore% or higher to pass.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 20),
                ...kTrainingQuizQuestions.map((q) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecorations.ecoCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.prompt, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          ...List.generate(q.options.length, (i) {
                            final selected = answers[q.id] == i;
                            return RadioListTile<int>(
                              value: i,
                              groupValue: answers[q.id],
                              onChanged: (v) {
                                if (v != null) onSelect(q.id, v);
                              },
                              title: Text(q.options[i], style: AppTextStyles.bodySecondary),
                              activeColor: AppColors.accent,
                              selected: selected,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(error!, style: AppTextStyles.body.copyWith(color: AppColors.error)),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(
              label: 'Submit quiz',
              isLoading: busy,
              onPressed: onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnsiteBody extends StatelessWidget {
  const _OnsiteBody({required this.record});

  final DriverTrainingRecord? record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Onsite training scheduled', style: AppTextStyles.headingLg),
          const SizedBox(height: 16),
          Text(
            'Your operator assigned onsite rider protocol training. Attend your scheduled session at the Carmona station — an admin will mark you complete in the portal.',
            style: AppTextStyles.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.ecoCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${record?.status.label ?? 'Not started'}',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                if (record?.adminNotes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(record!.adminNotes!, style: AppTextStyles.bodySecondary),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You cannot go Online until onsite training is marked complete.',
            style: AppTextStyles.bodySecondary.copyWith(color: AppColors.amber),
          ),
        ],
      ),
    );
  }
}

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({
    required this.record,
    required this.embedded,
    this.onContinue,
  });

  final DriverTrainingRecord record;
  final bool embedded;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.accent, size: 48),
          const SizedBox(height: 16),
          Text('Training complete', style: AppTextStyles.headingLg),
          const SizedBox(height: 8),
          Text(
            record.mode == TrainingMode.online
                ? 'Online quiz score: ${record.quizScore ?? '—'}%'
                : 'Onsite session verified by your operator.',
            style: AppTextStyles.bodySecondary,
          ),
          if (record.completedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Completed ${record.completedAt!.toLocal()}',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
            ),
          ],
          const Spacer(),
          if (embedded && onContinue != null)
            PrimaryButton(label: 'Continue to review', onPressed: onContinue)
          else if (!embedded)
            PrimaryButton(label: 'Go to Home', onPressed: () => context.go('/home')),
        ],
      ),
    );
  }
}
