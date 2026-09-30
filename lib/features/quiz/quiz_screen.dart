import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_assets.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/category_progress.dart';
import '../../data/models/final_exam.dart';
import '../../data/models/learning_activity.dart';
import '../../data/models/pending_quiz_attempt.dart';
import '../../data/models/quiz_question.dart';
import '../../data/models/quiz_result.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/category_progress_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/feedback/app_dialog.dart';
import '../../shared/services/connectivity_service.dart';
import '../../shared/services/pending_quiz_attempt_sync_service.dart';
import '../../shared/widgets/answer_option_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/character_image.dart';
import '../../shared/widgets/lesson_progress_bar.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/result_summary_card.dart';
import '../../shared/widgets/secondary_button.dart';
import 'activity_question_selector.dart';
import 'exam_question_selector.dart';
import 'quiz_controller.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen.activity({
    required this.category,
    required this.activity,
    required this.contentRepository,
    required this.progressController,
    this.totalActivities = 1,
    this.shuffleQuestions = true,
    this.shuffleOptions = true,
    this.connectivityService,
    this.authRepository,
    this.pendingSyncService,
    this.requireStartConfirmation = false,
    super.key,
  }) : exam = null,
       examQuestionSelector = null;

  const QuizScreen.exam({
    required this.category,
    required this.exam,
    required this.contentRepository,
    required this.progressController,
    this.totalActivities = 1,
    this.examQuestionSelector,
    this.shuffleQuestions = true,
    this.shuffleOptions = true,
    this.connectivityService,
    this.authRepository,
    this.pendingSyncService,
    this.requireStartConfirmation = false,
    super.key,
  }) : activity = null;

  final Category category;
  final LearningActivity? activity;
  final FinalExamConfig? exam;
  final ContentRepository contentRepository;
  final CategoryProgressController progressController;
  final int totalActivities;
  final ExamQuestionSelector? examQuestionSelector;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final ConnectivityService? connectivityService;
  final AuthRepository? authRepository;
  final PendingQuizAttemptSyncService? pendingSyncService;
  final bool requireStartConfirmation;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizQuestion>> _questionsFuture;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadQuestions();
  }

  void _retry() {
    setState(() {
      _showingResult = false;
      _questionsFuture = _loadQuestions();
    });
  }

  Future<List<QuizQuestion>> _loadQuestions() {
    final exam = widget.exam;
    if (exam != null) {
      return (widget.examQuestionSelector ?? const ExamQuestionSelector())
          .selectQuestions(
            contentRepository: widget.contentRepository,
            exam: exam,
          );
    }

    return const ActivityQuestionSelector().selectQuestions(
      contentRepository: widget.contentRepository,
      categoryId: widget.category.id,
      activity: widget.activity!,
    );
  }

  void _handleResultVisibilityChanged(bool isVisible) {
    if (_showingResult == isVisible) {
      return;
    }

    setState(() {
      _showingResult = isVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.quizTitle,
      automaticallyImplyLeading: !_showingResult,
      child: FutureBuilder<List<QuizQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('[Quiz] Content load failed.');
            }
            return _QuizLoadError(
              message: _loadErrorMessage(snapshot.error),
              onRetry: _retry,
            );
          }

          return _QuizFlow(
            category: widget.category,
            activity: widget.activity,
            exam: widget.exam,
            questions: snapshot.data!,
            progressController: widget.progressController,
            totalActivities: widget.totalActivities,
            shuffleQuestions: widget.shuffleQuestions,
            shuffleOptions: widget.shuffleOptions,
            connectivityService: widget.connectivityService,
            authRepository: widget.authRepository,
            pendingSyncService: widget.pendingSyncService,
            requireStartConfirmation: widget.requireStartConfirmation,
            onRestartRequested: _retry,
            onResultVisibilityChanged: _handleResultVisibilityChanged,
          );
        },
      ),
    );
  }

  String _loadErrorMessage(Object? error) {
    if (error is InsufficientExamQuestionsException) {
      return 'El banco actual tiene ${error.availableQuestions} preguntas. '
          'El examen final necesita ${error.requiredQuestions} para iniciar.';
    }

    return AppStrings.contentLoadError;
  }
}

class _QuizFlow extends StatefulWidget {
  const _QuizFlow({
    required this.category,
    required this.activity,
    required this.exam,
    required this.questions,
    required this.progressController,
    required this.totalActivities,
    required this.shuffleQuestions,
    required this.shuffleOptions,
    required this.connectivityService,
    required this.authRepository,
    required this.pendingSyncService,
    required this.requireStartConfirmation,
    required this.onRestartRequested,
    required this.onResultVisibilityChanged,
  });

  final Category category;
  final LearningActivity? activity;
  final FinalExamConfig? exam;
  final List<QuizQuestion> questions;
  final CategoryProgressController progressController;
  final int totalActivities;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final ConnectivityService? connectivityService;
  final AuthRepository? authRepository;
  final PendingQuizAttemptSyncService? pendingSyncService;
  final bool requireStartConfirmation;
  final VoidCallback onRestartRequested;
  final ValueChanged<bool> onResultVisibilityChanged;

  @override
  State<_QuizFlow> createState() => _QuizFlowState();
}

class _QuizFlowState extends State<_QuizFlow> with WidgetsBindingObserver {
  late final QuizController _controller;
  final TextEditingController _answerTextController = TextEditingController();
  final math.Random _characterRandom = math.Random();
  final Map<String, _ActivityCharacter> _activityCharacters =
      <String, _ActivityCharacter>{};
  bool _allowPop = false;
  bool _showResult = false;
  bool _isCompletingAttempt = false;
  bool _isCheckingStart = false;
  bool _attemptStarted = false;
  bool _resultPendingSync = false;
  QuizResult? _completedResult;
  String? _completedAttemptId;
  String? _activeAttemptId;
  AttemptReservation? _activeReservation;
  Future<void> _snapshotWriteTail = Future<void>.value();
  bool _snapshotFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = QuizController(
      questions: widget.questions,
      shuffleQuestions: widget.shuffleQuestions,
      shuffleOptions: widget.shuffleOptions,
    );
    WidgetsBinding.instance.addObserver(this);
    widget.progressController.addListener(_handleConfirmedProgress);
    if (!widget.requireStartConfirmation) {
      _beginAttempt();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.progressController.removeListener(_handleConfirmedProgress);
    _controller.dispose();
    _answerTextController.dispose();
    super.dispose();
  }

  void _handleConfirmedProgress() {
    if (!mounted ||
        !_showResult ||
        !_resultPendingSync ||
        _completedAttemptId == null) {
      return;
    }
    final attempt = widget.progressController.attemptFor(_completedAttemptId!);
    if (attempt?.completedAt != null) {
      setState(() => _resultPendingSync = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_attemptStarted ||
        _showResult ||
        _isCompletingAttempt ||
        _activeAttemptId == null) {
      return;
    }

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_finalizeCurrentAttempt(showResult: true));
    }
  }

  Future<void> _handleBackIntent() async {
    if (_showResult) {
      return;
    }

    if (!_attemptStarted) {
      _popQuizRoute();
      return;
    }

    final shouldExit = await AppDialog.showConfirmation(
      context,
      title: AppStrings.exitLessonTitle,
      message: AppStrings.exitLessonBody,
      cancelLabel: AppStrings.keepLearning,
      confirmLabel: AppStrings.exit,
      icon: Icons.logout_outlined,
      isDestructiveConfirm: true,
    );

    if (mounted && shouldExit) {
      await _finalizeCurrentAttempt(popOnComplete: true);
    }
  }

  void _popQuizRoute() {
    setState(() {
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _submitAnswer() {
    if (_isCompletingAttempt || _showResult) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_controller.submitAnswer()) {
      _snapshotWriteTail = _snapshotWriteTail
          .then((_) => _persistSubmittedAnswers())
          .catchError((Object _) {
            _snapshotFailed = true;
            if (kDebugMode) debugPrint('[Quiz] Pending answer save failed.');
          });
    }
  }

  Future<void> _completeAttemptAndShowResult() async {
    if (!_controller.isFinished) {
      return;
    }
    if (_isCompletingAttempt || _showResult) {
      return;
    }

    await _finalizeCurrentAttempt(showResult: true);
  }

  Future<void> _finalizeCurrentAttempt({
    bool showResult = false,
    bool popOnComplete = false,
  }) async {
    if (_isCompletingAttempt || _showResult) {
      return;
    }

    setState(() {
      _isCompletingAttempt = true;
    });

    final attemptId = _activeAttemptId;
    if (attemptId == null) {
      setState(() => _isCompletingAttempt = false);
      return;
    }
    await _snapshotWriteTail;
    try {
      await _persistSubmittedAnswers(
        status: PendingQuizAttemptSyncStatus.abandonedPendingFinalization,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isCompletingAttempt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.progressSaveError)),
        );
      }
      return;
    }

    final result = _controller.isFinished
        ? _controller.quizResult
        : _controller.partialResult;

    final saved = await _saveAttemptSnapshot(
      status: PendingQuizAttemptSyncStatus.pendingSync,
      completedAt: DateTime.now(),
    );
    if (widget.pendingSyncService != null && !saved) {
      if (mounted) {
        setState(() => _isCompletingAttempt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.progressSaveError)),
        );
      }
      return;
    }

    final isOnline =
        widget.connectivityService == null ||
        await widget.connectivityService!.checkConnection(force: true);
    if (!isOnline) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCompletingAttempt = false;
        _showResult = showResult;
        _resultPendingSync = true;
        _completedResult = result;
        _completedAttemptId = attemptId;
      });
      widget.onResultVisibilityChanged(showResult);
      if (popOnComplete) {
        _popQuizRoute();
      }
      return;
    }

    final completed =
        widget.pendingSyncService == null ||
            !widget.progressController.hasRemotePersistence
        ? await _completeStartedAttempt(attemptId, result)
        : await widget.pendingSyncService!.syncSavedAttempt(attemptId);
    if (!mounted) {
      return;
    }
    if (!completed) {
      setState(() {
        _isCompletingAttempt = false;
        _resultPendingSync = true;
        _completedResult = result;
        _completedAttemptId = attemptId;
        _showResult = showResult;
      });
      widget.onResultVisibilityChanged(showResult);
      if (popOnComplete) {
        _popQuizRoute();
      }
      return;
    }

    setState(() {
      _isCompletingAttempt = false;
      _showResult = showResult;
      _resultPendingSync = false;
      _completedResult = result;
      _completedAttemptId = attemptId;
    });
    widget.onResultVisibilityChanged(showResult);
    if (popOnComplete) {
      _popQuizRoute();
    }
  }

  Future<bool> _completeStartedAttempt(String attemptId, QuizResult result) {
    if (widget.exam != null) {
      return widget.progressController.completeExamAttempt(
        categoryId: widget.category.id,
        lessonId: widget.category.lessonId ?? widget.category.id,
        examId: widget.exam!.id,
        attemptId: attemptId,
        result: result,
        totalActivities: widget.totalActivities,
      );
    }

    return widget.progressController.completeActivityAttempt(
      categoryId: widget.category.id,
      lessonId: widget.category.lessonId ?? widget.category.id,
      activityId: widget.activity!.id,
      attemptId: attemptId,
      result: result,
      totalActivities: widget.totalActivities,
    );
  }

  Future<void> _goForward() async {
    if (_isCompletingAttempt || _showResult) return;
    await _snapshotWriteTail;
    if (_snapshotFailed) {
      try {
        await _persistSubmittedAnswers();
        _snapshotFailed = false;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.progressSaveError)),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    if (_controller.isLastQuestion) {
      unawaited(_completeAttemptAndShowResult());
      return;
    }

    _answerTextController.clear();
    _controller.goToNextActivity();
  }

  void _repeatLesson() {
    if (_resultPendingSync) {
      return;
    }
    if (widget.exam != null) {
      widget.onResultVisibilityChanged(false);
      widget.onRestartRequested();
      return;
    }

    _answerTextController.clear();
    _activityCharacters.clear();
    _snapshotFailed = false;
    _snapshotWriteTail = Future<void>.value();
    _controller.reset();
    setState(() {
      _allowPop = false;
      _showResult = false;
      _isCompletingAttempt = false;
      _attemptStarted = false;
      _resultPendingSync = false;
      _completedAttemptId = null;
      _activeAttemptId = null;
      _activeReservation = null;
      _completedResult = null;
    });
    if (widget.requireStartConfirmation) {
      unawaited(_confirmAndStartAttempt());
    } else {
      _beginAttempt();
    }
    widget.onResultVisibilityChanged(false);
  }

  void _backToActivities() {
    setState(() {
      _allowPop = true;
    });
    widget.onResultVisibilityChanged(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    });
  }

  _ActivityCharacter _characterForCurrentActivity() {
    return _activityCharacters.putIfAbsent(
      _controller.currentQuestionId,
      () => _characterRandom.nextBool()
          ? _ActivityCharacter.girl
          : _ActivityCharacter.boy,
    );
  }

  void _beginAttempt() {
    if (_attemptStarted) {
      return;
    }
    _activeAttemptId = _startAttempt();
    _attemptStarted = true;
    unawaited(
      _saveAttemptSnapshot(status: PendingQuizAttemptSyncStatus.inProgress),
    );
  }

  Future<void> _confirmAndStartAttempt() async {
    if (_isCheckingStart || _attemptStarted) {
      return;
    }
    setState(() {
      _isCheckingStart = true;
    });

    final isOnline =
        widget.connectivityService == null ||
        await widget.connectivityService!.checkConnection(force: true);
    if (!mounted) {
      return;
    }
    if (!isOnline) {
      setState(() {
        _isCheckingStart = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.startAttemptConnectionError)),
      );
      return;
    }

    final reservation = await _startReservedAttempt();
    if (!mounted) {
      return;
    }
    if (reservation == null) {
      setState(() => _isCheckingStart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.startAttemptConnectionError)),
      );
      return;
    }
    _activeAttemptId = reservation.attemptId;
    _activeReservation = reservation;
    final saved = await _saveAttemptSnapshot(
      status: PendingQuizAttemptSyncStatus.inProgress,
    );
    if (!mounted) {
      return;
    }
    if (widget.pendingSyncService != null && !saved) {
      widget.progressController.discardAttempt(reservation.attemptId);
      _activeAttemptId = null;
      _activeReservation = null;
      setState(() => _isCheckingStart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.progressSaveError)),
      );
      return;
    }
    _attemptStarted = true;
    setState(() => _isCheckingStart = false);
  }

  Future<AttemptReservation?> _startReservedAttempt() {
    final exam = widget.exam;
    if (exam != null) {
      return widget.progressController.reserveAndStartExamAttempt(
        categoryId: widget.category.id,
        lessonId: widget.category.lessonId ?? widget.category.id,
        examId: exam.id,
        questionIds: _controller.questionIds,
        totalActivities: widget.totalActivities,
      );
    }
    return widget.progressController.reserveAndStartActivityAttempt(
      categoryId: widget.category.id,
      lessonId: widget.category.lessonId ?? widget.category.id,
      activityId: widget.activity!.id,
      questionIds: _canonicalActivityQuestionIds,
      totalActivities: widget.totalActivities,
    );
  }

  String _startAttempt() {
    final exam = widget.exam;
    if (exam != null) {
      return widget.progressController.startExamAttempt(
        categoryId: widget.category.id,
        lessonId: widget.category.lessonId ?? widget.category.id,
        examId: exam.id,
        questionIds: _controller.questionIds,
        totalActivities: widget.totalActivities,
      );
    }

    return widget.progressController.startActivityAttempt(
      categoryId: widget.category.id,
      lessonId: widget.category.lessonId ?? widget.category.id,
      activityId: widget.activity!.id,
      questionIds: _controller.questionIds,
      totalActivities: widget.totalActivities,
    );
  }

  Future<void> _persistSubmittedAnswers({
    PendingQuizAttemptSyncStatus status =
        PendingQuizAttemptSyncStatus.inProgress,
  }) async {
    final attemptId = _activeAttemptId;
    if (attemptId == null) {
      return;
    }

    for (final answer in _controller.submittedAnswers) {
      await widget.progressController.recordAnswer(
        categoryId: widget.category.id,
        activityId: widget.activity?.id,
        examId: widget.exam?.id,
        attemptId: attemptId,
        questionId: answer.questionId,
        answer: answer.answer,
        isCorrect: answer.isCorrect,
      );
    }
    final saved = await _saveAttemptSnapshot(status: status);
    if (widget.pendingSyncService != null && !saved) {
      throw StateError('Could not persist quiz snapshot.');
    }
  }

  Future<bool> _saveAttemptSnapshot({
    required PendingQuizAttemptSyncStatus status,
    DateTime? completedAt,
  }) async {
    final syncService = widget.pendingSyncService;
    final user = widget.authRepository?.currentUser;
    final attemptId = _activeAttemptId;
    if (syncService == null || user == null) {
      return false;
    }
    if (attemptId == null) {
      return false;
    }

    final attempt = widget.progressController.attemptFor(attemptId);
    if (attempt == null) {
      return false;
    }
    final result = _controller.partialResult;
    final answeredAt = DateTime.now();
    final type = widget.exam == null
        ? QuizAttemptType.activity
        : QuizAttemptType.exam;
    final pending = PendingQuizAttempt(
      uid: user.uid,
      attemptId: attemptId,
      attemptNumber: attempt.attemptNumber,
      type: type,
      categoryId: widget.category.id,
      lessonId: widget.category.lessonId ?? widget.category.id,
      activityId: widget.activity?.id,
      examId: widget.exam?.id,
      questionIds: widget.exam == null
          ? _canonicalActivityQuestionIds
          : _controller.questionIds,
      answers: [
        for (final answer in _controller.submittedAnswers)
          CategoryProgressAnswer(
            questionId: answer.questionId,
            answer: answer.answer,
            isCorrect: answer.isCorrect,
            answeredAt: completedAt ?? answeredAt,
          ),
      ],
      pointValue: widget.exam == null ? _activeReservation?.pointValue : null,
      correctQuestionIds: [
        for (final answer in _controller.submittedAnswers)
          if (answer.isCorrect) answer.questionId,
      ],
      correctAnswers: result.correctAnswers,
      totalQuestions: result.totalQuestions,
      percentage: result.percentage,
      totalActivities: widget.totalActivities,
      startedAt: attempt.startedAt,
      completedAt: completedAt,
      status: status,
    );
    try {
      await syncService.savePending(pending);
      return true;
    } catch (_) {
      if (kDebugMode) debugPrint('[Quiz] Pending answer save failed.');
      return false;
    }
  }

  List<String> get _canonicalActivityQuestionIds =>
      [for (final question in widget.questions) question.id]..sort();

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackIntent();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_showResult) {
            final completedAttempt = _completedAttemptId == null
                ? null
                : widget.progressController.attemptFor(_completedAttemptId!);
            return _ResultView(
              result: _completedResult ?? _controller.generateResult(),
              takeaways:
                  widget.activity?.completion.takeaways ?? const <String>[],
              earnedPoints: _resultPendingSync
                  ? null
                  : completedAttempt?.earnedPoints,
              totalPoints: _resultPendingSync
                  ? null
                  : widget.progressController.currentTotalPoints,
              pendingSync: _resultPendingSync,
              onBackToActivities: _backToActivities,
              onRepeatLesson: _repeatLesson,
            );
          }

          if (!_attemptStarted) {
            return _StartAttemptView(
              isExam: widget.exam != null,
              isChecking: _isCheckingStart,
              onStart: _confirmAndStartAttempt,
              onCancel: _popQuizRoute,
            );
          }

          return _ActivityView(
            controller: _controller,
            activityCharacter: _characterForCurrentActivity(),
            answerTextController: _answerTextController,
            onSubmitAnswer: _submitAnswer,
            onGoForward: _goForward,
            isCompletingAttempt: _isCompletingAttempt,
          );
        },
      ),
    );
  }
}

class _ActivityView extends StatelessWidget {
  const _ActivityView({
    required this.controller,
    required this.activityCharacter,
    required this.answerTextController,
    required this.onSubmitAnswer,
    required this.onGoForward,
    required this.isCompletingAttempt,
  });

  final QuizController controller;
  final _ActivityCharacter activityCharacter;
  final TextEditingController answerTextController;
  final VoidCallback onSubmitAnswer;
  final VoidCallback onGoForward;
  final bool isCompletingAttempt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LessonProgressBar(
          currentStep: controller.currentQuestionNumber,
          totalSteps: controller.totalQuestions,
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: AppSpacing.md + bottomInset),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ActivityIllustration(
                  controller: controller,
                  activityCharacter: activityCharacter,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  controller.currentStatement,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                _AnswerInput(
                  controller: controller,
                  textController: answerTextController,
                  onSubmitAnswer: onSubmitAnswer,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (controller.isAnswerConfirmed)
          PrimaryButton(
            label: controller.isLastQuestion
                ? AppStrings.seeResult
                : AppStrings.nextActivity,
            icon: controller.isLastQuestion
                ? Icons.assessment_outlined
                : Icons.arrow_forward_outlined,
            onPressed: isCompletingAttempt ? null : onGoForward,
          )
        else if (controller.canSubmitAnswer)
          Align(
            alignment: Alignment.centerRight,
            child: _CompactSubmitButton(onPressed: onSubmitAnswer),
          ),
      ],
    );
  }
}

class _StartAttemptView extends StatelessWidget {
  const _StartAttemptView({
    required this.isExam,
    required this.isChecking,
    required this.onStart,
    required this.onCancel,
  });

  final bool isExam;
  final bool isChecking;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        child: Card(
          color: colors.surfaceStrong,
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  color: colors.orangeDark,
                  size: 36,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isExam
                      ? AppStrings.startExamAttemptTitle
                      : AppStrings.startAttemptTitle,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.startAttemptBody,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: AppStrings.startAttempt,
                  icon: Icons.play_arrow_outlined,
                  onPressed: isChecking ? null : onStart,
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: AppStrings.cancel,
                  icon: Icons.close_outlined,
                  onPressed: isChecking ? null : onCancel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSubmitButton extends StatelessWidget {
  const _CompactSubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.submitAnswer,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_outlined),
        label: const Text(AppStrings.submitAnswer),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}

class _AnswerInput extends StatelessWidget {
  const _AnswerInput({
    required this.controller,
    required this.textController,
    required this.onSubmitAnswer,
  });

  final QuizController controller;
  final TextEditingController textController;
  final VoidCallback onSubmitAnswer;

  @override
  Widget build(BuildContext context) {
    return switch (controller.currentQuestionType) {
      QuestionType.multipleChoice ||
      QuestionType.trueFalse => _ChoiceOptions(controller: controller),
      QuestionType.fillBlank => _FillBlankInput(
        controller: controller,
        textController: textController,
        onSubmitAnswer: onSubmitAnswer,
      ),
    };
  }
}

class _ActivityIllustration extends StatelessWidget {
  const _ActivityIllustration({
    required this.controller,
    required this.activityCharacter,
  });

  final QuizController controller;
  final _ActivityCharacter activityCharacter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final assetPath = _assetForState(controller);
    final titleText = _titleTextForState(controller);
    final bodyText = _bodyTextForState(controller);

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useVerticalLayout =
                constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.35;
            final characterWidth = (constraints.maxWidth - 150).clamp(
              140.0,
              190.0,
            );
            const horizontalImageHeight = AppSizing.characterFeatureHeight;
            const verticalImageHeight = AppSizing.characterInlineHeight;
            final image = AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: CharacterImage(
                key: ValueKey(assetPath),
                assetPath: assetPath,
                semanticLabel: '$titleText. $bodyText',
                height: useVerticalLayout
                    ? verticalImageHeight
                    : horizontalImageHeight,
              ),
            );
            final illustratedState = Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                image,
                if (!reduceMotion &&
                    controller.isAnswerConfirmed &&
                    controller.isCurrentAnswerCorrect == true)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _CorrectConfetti(
                        key: ValueKey(controller.currentQuestionId),
                      ),
                    ),
                  ),
              ],
            );
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _iconForState(controller),
                      color: _colorForState(colors),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        titleText,
                        style: textTheme.titleSmall?.copyWith(
                          color: controller.isAnswerConfirmed
                              ? _colorForState(colors)
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  bodyText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (controller.isAnswerConfirmed &&
                    controller.isCurrentAnswerCorrect == false &&
                    controller.currentQuestionType ==
                        QuestionType.fillBlank) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _RecommendedAnswerText(controller: controller),
                ],
              ],
            );
            final constrainedIllustration = SizedBox(
              width: characterWidth,
              height: horizontalImageHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                child: illustratedState,
              ),
            );

            if (useVerticalLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: SizedBox(
                      height: verticalImageHeight,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: illustratedState,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: content),
                const SizedBox(width: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: constrainedIllustration,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _assetForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      if (controller.isCurrentAnswerCorrect == true) {
        return activityCharacter.correctAsset;
      }

      return activityCharacter.incorrectAsset;
    }

    return activityCharacter.normalAsset;
  }

  String _titleTextForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      if (controller.isCurrentAnswerCorrect == true) {
        return AppStrings.correct;
      }

      return AppStrings.reviewAnswer;
    }

    return 'Antes de responder';
  }

  String _bodyTextForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      return controller.currentFeedback ?? '';
    }

    if (controller.currentQuestionType == QuestionType.fillBlank) {
      return 'Piensa en una palabra breve y concreta.';
    }

    return 'Lee la situación y elige la respuesta más segura.';
  }

  IconData _iconForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      return controller.isCurrentAnswerCorrect == true
          ? Icons.check_circle_outline
          : Icons.cancel_outlined;
    }

    return controller.currentQuestionType == QuestionType.fillBlank
        ? Icons.lightbulb_outline
        : Icons.psychology_outlined;
  }

  Color _colorForState(AppColors colors) {
    if (!controller.isAnswerConfirmed) {
      return colors.orangeDark;
    }

    return controller.isCurrentAnswerCorrect == true
        ? colors.success
        : colors.error;
  }
}

class _RecommendedAnswerText extends StatelessWidget {
  const _RecommendedAnswerText({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label:
          '${AppStrings.expectedAnswer}: ${controller.currentCorrectAnswerText}',
      child: Text(
        '${AppStrings.expectedAnswer}: ${controller.currentCorrectAnswerText}',
        style: textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _ActivityCharacter {
  boy(
    normalAsset: AppAssets.activityBoyNormal,
    correctAsset: AppAssets.activityBoyCorrect,
    incorrectAsset: AppAssets.activityBoyIncorrect,
  ),
  girl(
    normalAsset: AppAssets.activityGirlNormal,
    correctAsset: AppAssets.activityGirlCorrect,
    incorrectAsset: AppAssets.activityGirlIncorrect,
  );

  const _ActivityCharacter({
    required this.normalAsset,
    required this.correctAsset,
    required this.incorrectAsset,
  });

  final String normalAsset;
  final String correctAsset;
  final String incorrectAsset;
}

class _CorrectConfetti extends StatefulWidget {
  const _CorrectConfetti({super.key});

  @override
  State<_CorrectConfetti> createState() => _CorrectConfettiState();
}

class _CorrectConfettiState extends State<_CorrectConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = <Color>[
    Color(0xFFFF8A00),
    Color(0xFFFFC107),
    Color(0xFF2E7D32),
    Color(0xFF7B1FA2),
    Color(0xFF2196F3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.35);

    for (var index = 0; index < 18; index += 1) {
      final angle = (-130 + (index * 260 / 17)) * math.pi / 180;
      final distance = (32 + (index % 5) * 8) * eased;
      final drift = Offset(math.cos(angle), math.sin(angle)) * distance;
      final fall = Offset(0, 18 * progress * progress);
      final position = center + drift + fall;
      final paint = Paint()
        ..color = _colors[index % _colors.length].withValues(alpha: opacity);
      final width = 5.0 + (index % 3);
      final height = 9.0 + (index % 2) * 3.0;

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final visibleOptions = _visibleOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in visibleOptions) ...[
          AnswerOptionTile(
            text: option.text,
            state: _stateForOption(option.id),
            onTap: controller.isAnswerConfirmed
                ? null
                : () => controller.selectOption(option.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  List<QuizOption> _visibleOptions() {
    if (!controller.isAnswerConfirmed) {
      return controller.currentOptions;
    }

    final selectedOption = controller.currentOptions.firstWhere(
      (option) => option.id == controller.selectedOptionId,
    );
    final correctOption = controller.currentOptions.firstWhere(
      (option) => option.id == controller.currentCorrectAnswerId,
    );

    if (selectedOption.id == correctOption.id) {
      return <QuizOption>[selectedOption];
    }

    return <QuizOption>[selectedOption, correctOption];
  }

  AnswerOptionTileState _stateForOption(String optionId) {
    if (!controller.isAnswerConfirmed) {
      return controller.selectedOptionId == optionId
          ? AnswerOptionTileState.selected
          : AnswerOptionTileState.idle;
    }

    if (optionId == controller.currentCorrectAnswerId) {
      return AnswerOptionTileState.correct;
    }

    if (optionId == controller.selectedOptionId) {
      return AnswerOptionTileState.incorrect;
    }

    return AnswerOptionTileState.idle;
  }
}

class _FillBlankInput extends StatelessWidget {
  const _FillBlankInput({
    required this.controller,
    required this.textController,
    required this.onSubmitAnswer,
  });

  final QuizController controller;
  final TextEditingController textController;
  final VoidCallback onSubmitAnswer;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      enabled: !controller.isAnswerConfirmed,
      maxLength: 32,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        LengthLimitingTextInputFormatter(32),
        FilteringTextInputFormatter.deny(RegExp(r'\s{2,}')),
      ],
      decoration: InputDecoration(
        labelText: AppStrings.fillBlankHint,
        counterText: '',
      ),
      onChanged: controller.updateWrittenAnswer,
      onSubmitted: (_) {
        if (controller.canSubmitAnswer) {
          onSubmitAnswer();
        }
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.takeaways,
    required this.earnedPoints,
    required this.totalPoints,
    required this.pendingSync,
    required this.onBackToActivities,
    required this.onRepeatLesson,
  });

  final QuizResult result;
  final List<String> takeaways;
  final int? earnedPoints;
  final int? totalPoints;
  final bool pendingSync;
  final VoidCallback onBackToActivities;
  final VoidCallback onRepeatLesson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: ResultSummaryCard(
              result: result,
              takeaways: takeaways,
              earnedPoints: earnedPoints,
              totalPoints: totalPoints,
            ),
          ),
        ),
        if (pendingSync) ...[
          const SizedBox(height: AppSpacing.md),
          const _PendingSyncNotice(),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: AppStrings.backToActivities,
          icon: Icons.format_list_bulleted_outlined,
          onPressed: onBackToActivities,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: AppStrings.repeatLesson,
          icon: Icons.refresh_outlined,
          onPressed: pendingSync ? null : onRepeatLesson,
        ),
      ],
    );
  }
}

class _PendingSyncNotice extends StatelessWidget {
  const _PendingSyncNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      color: colors.orangeSoft,
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sync_outlined, color: colors.orangeDark),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.pendingSyncTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(AppStrings.pendingSyncBody),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizLoadError extends StatelessWidget {
  const _QuizLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: AppStrings.retry,
              icon: Icons.refresh_outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
