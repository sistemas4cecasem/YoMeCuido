enum ObservabilityOperation {
  bootstrap,
  initializeFirebase,
  initializeAppCheck,
  initializeObservability,
  framework,
  asynchronousTask,
  authentication,
  loadContent,
  loadProfile,
  saveProfile,
  loadProgress,
  finalizeAttempt,
  pendingStorage,
  pendingSync,
  recovery,
  deleteAccount,
  crashlyticsQa,
}

enum ObservabilityErrorCode {
  unavailable,
  permissionDenied,
  invalidData,
  invariantViolation,
  unexpected,
  localReadFailed,
  localWriteFailed,
}

enum ObservabilityCategory {
  initialization,
  framework,
  authentication,
  content,
  storage,
  persistence,
}

// Final prevents callers from overriding diagnostics with arbitrary text.
final class ObservabilityEvent {
  const ObservabilityEvent({
    required this.operation,
    required this.code,
    required this.category,
    this.fatal = false,
  });

  final ObservabilityOperation operation;
  final ObservabilityErrorCode code;
  final ObservabilityCategory category;
  final bool fatal;
}

abstract interface class ObservabilityService {
  Future<void> record(ObservabilityEvent event);
}

final class NoOpObservabilityService implements ObservabilityService {
  const NoOpObservabilityService();

  @override
  Future<void> record(ObservabilityEvent event) async {}
}

final class SessionObservabilityService implements ObservabilityService {
  factory SessionObservabilityService(ObservabilityService delegate) =>
      delegate is SessionObservabilityService
      ? delegate
      : SessionObservabilityService._(delegate);

  SessionObservabilityService._(this._delegate);

  static const maxEventsPerSession = 64;
  final ObservabilityService _delegate;
  final _seen =
      <
        (
          ObservabilityOperation,
          ObservabilityErrorCode,
          ObservabilityCategory,
          bool,
        )
      >{};

  @override
  Future<void> record(ObservabilityEvent event) async {
    final key = (event.operation, event.code, event.category, event.fatal);
    if (_seen.length >= maxEventsPerSession || !_seen.add(key)) return;
    try {
      await _delegate.record(event);
    } catch (_) {
      // Observability is secondary: never recurse or replace the original error.
    }
  }
}
