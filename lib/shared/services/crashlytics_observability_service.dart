import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'observability_service.dart';
import 'error_observation.dart';

final class CrashlyticsObservabilityService implements ObservabilityService {
  CrashlyticsObservabilityService({
    required FirebaseCrashlytics crashlytics,
    bool reportingEnabled = false,
  }) : _crashlytics = crashlytics,
       _reportingEnabled = reportingEnabled;

  final FirebaseCrashlytics _crashlytics;
  final bool _reportingEnabled;

  // An empty stack would be replaced by the caller's stack by FlutterFire.
  static final _syntheticStack = StackTrace.fromString(
    '#0      YoMeCuidoDiagnostic.record '
    '(package:demo_yomecuido/shared/services/'
    'crashlytics_observability_service.dart:1:1)',
  );

  @override
  Future<void> record(ObservabilityEvent event) async {
    await _record(event);
  }

  Future<bool> recordQaNonFatal() async {
    if (!kDebugMode) return false;
    return _record(
      const ObservabilityEvent(
        operation: ObservabilityOperation.crashlyticsQa,
        code: ObservabilityErrorCode.unexpected,
        category: ObservabilityCategory.initialization,
      ),
    );
  }

  Future<bool> _record(ObservabilityEvent event) async {
    if (!_reportingEnabled) return false;
    if (event.operation == ObservabilityOperation.crashlyticsQa &&
        (!kDebugMode || event.fatal)) {
      return false;
    }
    try {
      if (!_crashlytics.isCrashlyticsCollectionEnabled) return false;
      await _crashlytics.recordError(
        _SafeDiagnostic(event),
        _syntheticStack,
        fatal: event.fatal,
        printDetails: false,
      );
      return true;
    } catch (_) {
      _logUnavailable();
      return false;
    }
  }
}

// Current environments always use NoOp; activation belongs to phase 6.4.
Future<ObservabilityService> initializeDisabledObservability({
  FirebaseCrashlytics? crashlytics,
  ObservabilityService observabilityService = const NoOpObservabilityService(),
}) async {
  try {
    final client = crashlytics ?? FirebaseCrashlytics.instance;
    // Runtime preferences override the manifest and persist across launches.
    await client.setCrashlyticsCollectionEnabled(false);
    if (!client.isCrashlyticsCollectionEnabled) {
      await client.deleteUnsentReports();
    } else {
      _logUnavailable();
      observeUnexpectedError(
        observabilityService,
        StateError('Collection was not disabled.'),
        operation: ObservabilityOperation.initializeObservability,
        category: ObservabilityCategory.initialization,
      );
    }
  } catch (error) {
    _logUnavailable();
    observeUnexpectedError(
      observabilityService,
      error,
      operation: ObservabilityOperation.initializeObservability,
      category: ObservabilityCategory.initialization,
    );
  }
  return const NoOpObservabilityService();
}

final class _SafeDiagnostic implements Exception {
  const _SafeDiagnostic(this.event);

  final ObservabilityEvent event;

  @override
  String toString() => event.operation == ObservabilityOperation.crashlyticsQa
      ? 'YMC_CRASHLYTICS_QA_NONFATAL'
      : 'YoMeCuidoDiagnostic('
            '${event.operation.name}, ${event.code.name}, ${event.category.name})';
}

void _logUnavailable() {
  if (kDebugMode) {
    debugPrint('[Observability] Unavailable; continuing without reports.');
  }
}
