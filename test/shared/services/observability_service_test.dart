import 'package:demo_yomecuido/shared/services/crashlytics_observability_service.dart';
import 'package:demo_yomecuido/shared/services/observability_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _event = ObservabilityEvent(
  operation: ObservabilityOperation.pendingStorage,
  code: ObservabilityErrorCode.invalidData,
  category: ObservabilityCategory.storage,
);

void main() {
  test('NoOp accepts approved codes without initializing Firebase', () async {
    expect(Firebase.apps, isEmpty);
    const service = NoOpObservabilityService();
    for (final operation in ObservabilityOperation.values) {
      for (final code in ObservabilityErrorCode.values) {
        for (final category in ObservabilityCategory.values) {
          await service.record(
            ObservabilityEvent(
              operation: operation,
              code: code,
              category: category,
            ),
          );
        }
      }
    }
    expect(Firebase.apps, isEmpty);
  });

  test('event contract rejects arbitrary text in every code field', () {
    for (final field in [#operation, #code, #category, #fatal]) {
      final arguments = <Symbol, Object>{
        #operation: ObservabilityOperation.pendingStorage,
        #code: ObservabilityErrorCode.invalidData,
        #category: ObservabilityCategory.storage,
        #fatal: false,
        field: 'uid-persona@example.com-token-answer',
      };
      expect(
        () => Function.apply(ObservabilityEvent.new, [], arguments),
        throwsA(isA<TypeError>()),
      );
    }
  });

  test('event contract rejects raw exceptions and arbitrary stacks', () {
    for (final forbiddenField in [#exception, #message, #stackTrace, #uid]) {
      expect(
        () => Function.apply(ObservabilityEvent.new, [], <Symbol, Object>{
          #operation: ObservabilityOperation.pendingStorage,
          #code: ObservabilityErrorCode.invalidData,
          #category: ObservabilityCategory.storage,
          forbiddenField: const FormatException(
            'private',
            '{"uid":"private","answers":["private"]}',
          ),
        }),
        throwsNoSuchMethodError,
      );
    }
  });

  test('adapter defaults to no recording even with an enabled SDK', () async {
    final client = _FakeCrashlytics(collectionEnabled: true);
    final service = CrashlyticsObservabilityService(crashlytics: client);
    await service.record(_event);
    expect(client.calls, isEmpty);
    expect(client.reports, isEmpty);
  });

  test(
    'adapter never queues reports when SDK collection is disabled',
    () async {
      final client = _FakeCrashlytics();
      final service = CrashlyticsObservabilityService(
        crashlytics: client,
        reportingEnabled: true,
      );
      await service.record(_event);
      expect(client.reports, isEmpty);
    },
  );

  test('prepared adapter builds only safe synthetic diagnostics', () async {
    final client = _FakeCrashlytics(collectionEnabled: true);
    final service = CrashlyticsObservabilityService(
      crashlytics: client,
      reportingEnabled: true,
    );
    await service.record(_event);
    final report = client.reports.single;
    expect(
      report.message,
      'YoMeCuidoDiagnostic(pendingStorage, invalidData, storage)',
    );
    expect(report.stack, startsWith('#0      YoMeCuidoDiagnostic.record '));
    expect(report.stack, contains('package:demo_yomecuido/'));
    expect(report.stack, isNot(contains('observability_service_test.dart')));
    expect(report.reason, isNull);
    expect(report.information, isEmpty);
    expect(report.printDetails, isFalse);
    expect(report.fatal, isFalse);
    expect(Firebase.apps, isEmpty);
  });

  test('fatal indicator is preserved only in the fake transport', () async {
    final client = _FakeCrashlytics(collectionEnabled: true);
    final service = CrashlyticsObservabilityService(
      crashlytics: client,
      reportingEnabled: true,
    );
    await service.record(
      const ObservabilityEvent(
        operation: ObservabilityOperation.framework,
        code: ObservabilityErrorCode.unexpected,
        category: ObservabilityCategory.framework,
        fatal: true,
      ),
    );
    expect(client.reports.single.fatal, isTrue);
  });

  test(
    'bootstrap replaces persisted enablement before discarding reports',
    () async {
      final client = _FakeCrashlytics(collectionEnabled: true);
      final service = await initializeDisabledObservability(
        crashlytics: client,
      );
      expect(client.calls, ['collection:false', 'deleteUnsentReports']);
      expect(client.collectionEnabled, isFalse);
      expect(service, isA<NoOpObservabilityService>());
      await service.record(_event);
      expect(client.reports, isEmpty);
    },
  );

  test(
    'bootstrap returns NoOp when Firebase has not been initialized',
    () async {
      expect(Firebase.apps, isEmpty);
      final service = await initializeDisabledObservability();
      expect(service, isA<NoOpObservabilityService>());
      await service.record(_event);
      expect(Firebase.apps, isEmpty);
    },
  );

  test(
    'initialization failures do not expose secrets or break startup',
    () async {
      final messages = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
      addTearDown(() => debugPrint = original);
      for (final failDuringDisable in [true, false]) {
        final client = _FakeCrashlytics(
          failDuringDisable: failDuringDisable,
          failDuringDelete: !failDuringDisable,
        );
        final service = await initializeDisabledObservability(
          crashlytics: client,
        );
        expect(service, isA<NoOpObservabilityService>());
        await service.record(_event);
        expect(client.reports, isEmpty);
      }
      expect(messages, hasLength(2));
      expect(messages.join(), isNot(contains('persona@example.com')));
      expect(messages.join(), isNot(contains('private-token')));
    },
  );

  test('reporter failures do not escape to functional operations', () async {
    final client = _FakeCrashlytics(
      collectionEnabled: true,
      failDuringRecord: true,
    );
    final service = CrashlyticsObservabilityService(
      crashlytics: client,
      reportingEnabled: true,
    );
    await expectLater(service.record(_event), completes);
  });

  test(
    'bootstrap classifies SDK failure safely even when observer fails',
    () async {
      final observer = _FailingObserver();
      final client = _FakeCrashlytics(failDuringDelete: true);
      final service = await initializeDisabledObservability(
        crashlytics: client,
        observabilityService: observer,
      );
      expect(service, isA<NoOpObservabilityService>());
      expect(client.collectionEnabled, isFalse);
      expect(client.reports, isEmpty);
      expect(
        observer.events.single.operation,
        ObservabilityOperation.initializeObservability,
      );
      expect(observer.events.single.code, ObservabilityErrorCode.invalidData);
      expect(
        observer.events.single.category,
        ObservabilityCategory.initialization,
      );
    },
  );
}

class _FailingObserver implements ObservabilityService {
  final events = <ObservabilityEvent>[];

  @override
  Future<void> record(ObservabilityEvent event) async {
    events.add(event);
    throw StateError('secondary-private');
  }
}

class _FakeCrashlytics implements FirebaseCrashlytics {
  _FakeCrashlytics({
    this.collectionEnabled = false,
    this.failDuringDisable = false,
    this.failDuringDelete = false,
    this.failDuringRecord = false,
  });

  bool collectionEnabled;
  final bool failDuringDisable;
  final bool failDuringDelete;
  final bool failDuringRecord;
  final calls = <String>[];
  final reports = <_RecordedReport>[];

  static const _privateFailure = FormatException(
    'persona@example.com private-token',
    '{"uid":"private","answers":["private"]}',
  );

  @override
  bool get isCrashlyticsCollectionEnabled => collectionEnabled;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    calls.add('collection:$enabled');
    if (failDuringDisable) throw _privateFailure;
    collectionEnabled = enabled;
  }

  @override
  Future<void> deleteUnsentReports() async {
    expect(collectionEnabled, isFalse);
    calls.add('deleteUnsentReports');
    if (failDuringDelete) throw _privateFailure;
  }

  @override
  Future<void> recordError(
    Object? exception,
    StackTrace? stack, {
    Object? reason,
    Iterable<Object> information = const [],
    bool? printDetails,
    bool fatal = false,
  }) async {
    if (failDuringRecord) throw _privateFailure;
    reports.add(
      _RecordedReport(
        message: exception.toString(),
        stack: stack?.toString(),
        reason: reason,
        information: information.toList(),
        printDetails: printDetails,
        fatal: fatal,
      ),
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected SDK call: ${invocation.memberName}');
}

class _RecordedReport {
  const _RecordedReport({
    required this.message,
    required this.stack,
    required this.reason,
    required this.information,
    required this.printDetails,
    required this.fatal,
  });

  final String message;
  final String? stack;
  final Object? reason;
  final List<Object> information;
  final bool? printDetails;
  final bool fatal;
}
