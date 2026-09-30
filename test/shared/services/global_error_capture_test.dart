import 'dart:async';

import 'package:demo_yomecuido/shared/services/error_observation.dart';
import 'package:demo_yomecuido/shared/services/global_error_capture.dart';
import 'package:demo_yomecuido/shared/services/observability_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Observer observer;
  late GlobalErrorCapture capture;
  late List<FlutterErrorDetails> presented;

  setUp(() {
    final flutterHandler = FlutterError.onError;
    final platformHandler = PlatformDispatcher.instance.onError;
    addTearDown(() {
      capture.restore();
      FlutterError.onError = flutterHandler;
      PlatformDispatcher.instance.onError = platformHandler;
    });
    presented = [];
    FlutterError.onError = presented.add;
    PlatformDispatcher.instance.onError = null;
    observer = _Observer();
    capture = GlobalErrorCapture(observabilityService: observer);
  });

  test(
    'Flutter error is classified and standard handler receives originals',
    () {
      capture.install();
      var collected = false;
      final details = FlutterErrorDetails(
        exception: StateError('uid-private persona@example.com'),
        stack: StackTrace.fromString('users/uid-private/attempt-private'),
        informationCollector: () {
          collected = true;
          return [StringProperty('answer', 'private-answer')];
        },
      );
      FlutterError.reportError(details);
      expect(presented.single, same(details));
      expect(collected, isFalse);
      final event = observer.events.single;
      expect(event.operation, ObservabilityOperation.framework);
      expect(event.code, ObservabilityErrorCode.invariantViolation);
      expect(event.category, ObservabilityCategory.framework);
      expect(event.fatal, isFalse);
      expect(_payload(event), isNot(contains('private')));
    },
  );

  test('unhandled async callback reports safely and returns false', () {
    capture.install();
    final handled = PlatformDispatcher.instance.onError!(
      const FormatException('uid-private', '{"answers":["private-answer"]}'),
      StackTrace.fromString('private-token'),
    );
    expect(handled, isFalse);
    final event = observer.events.single;
    expect(event.operation, ObservabilityOperation.asynchronousTask);
    expect(event.code, ObservabilityErrorCode.invalidData);
    expect(event.fatal, isTrue);
    expect(_payload(event), isNot(contains('private')));
  });

  test('previous async handler retains its error, stack and return value', () {
    final error = Exception('private-answer');
    final stack = StackTrace.fromString('private-path');
    PlatformDispatcher.instance.onError = (received, receivedStack) {
      expect(received, same(error));
      expect(receivedStack, same(stack));
      return true;
    };
    capture.install();
    expect(PlatformDispatcher.instance.onError!(error, stack), isTrue);
    expect(observer.events, hasLength(1));
  });

  test('install is idempotent and repeated errors emit once', () {
    capture.install();
    final handler = FlutterError.onError;
    capture.install();
    expect(FlutterError.onError, handler);
    for (var i = 0; i < 5; i++) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('$i')),
      );
    }
    expect(observer.events, hasLength(1));
    expect(presented, hasLength(5));
  });

  test('Firebase sensitive message never enters the event', () {
    capture.install();
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'uid-private users/uid-private private-token private-answer',
        ),
      ),
    );
    expect(
      observer.events.single.code,
      ObservabilityErrorCode.permissionDenied,
    );
    expect(_payload(observer.events.single), isNot(contains('private')));
  });

  test('classification never calls arbitrary exception.toString', () {
    capture.install();
    FlutterError.reportError(FlutterErrorDetails(exception: _PrivateError()));
    expect(observer.events.single.code, ObservabilityErrorCode.unexpected);
    expect(presented, hasLength(1));
  });

  test('expected Firebase codes and timeouts do not generate events', () {
    capture.install();
    for (final code in [
      'unavailable',
      'deadline-exceeded',
      'network-request-failed',
      'cancelled',
      'wrong-password',
      'invalid-credential',
      'requires-recent-login',
      'unauthenticated',
      'too-many-requests',
    ]) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FirebaseException(
            plugin: 'firebase_auth',
            code: code,
            message: 'private',
          ),
        ),
      );
    }
    FlutterError.reportError(
      FlutterErrorDetails(exception: TimeoutException('private')),
    );
    expect(observer.events, isEmpty);
    expect(presented, hasLength(10));
  });

  test('observer synchronous failure cannot hide Flutter diagnostics', () {
    observer.failure = StateError('secondary-private');
    capture.install();
    FlutterError.reportError(FlutterErrorDetails(exception: _PrivateError()));
    expect(presented, hasLength(1));
  });

  test('observer asynchronous failure is contained', () async {
    observer.failAsynchronously = true;
    capture.install();
    expect(
      PlatformDispatcher.instance.onError!(_PrivateError(), StackTrace.current),
      isFalse,
    );
    await Future<void>.delayed(Duration.zero);
    expect(observer.events, hasLength(1));
  });

  test('NoOp capture does not initialize Firebase', () {
    capture = GlobalErrorCapture(
      observabilityService: const NoOpObservabilityService(),
    );
    capture.install();
    FlutterError.reportError(FlutterErrorDetails(exception: _PrivateError()));
    expect(presented, hasLength(1));
    expect(Firebase.apps, isEmpty);
  });

  test('restore preserves handlers installed later by another owner', () {
    capture.install();
    void replacement(FlutterErrorDetails details) {}
    FlutterError.onError = replacement;
    capture.restore();
    expect(FlutterError.onError, replacement);
  });

  test('session dedup is concurrent-safe, shared and bounded', () async {
    final session = SessionObservabilityService(observer);
    expect(SessionObservabilityService(session), same(session));
    const event = ObservabilityEvent(
      operation: ObservabilityOperation.pendingStorage,
      code: ObservabilityErrorCode.localReadFailed,
      category: ObservabilityCategory.storage,
    );
    await Future.wait([for (var i = 0; i < 20; i++) session.record(event)]);
    expect(observer.events, hasLength(1));
    for (final operation in ObservabilityOperation.values) {
      for (final code in ObservabilityErrorCode.values) {
        await session.record(
          ObservabilityEvent(
            operation: operation,
            code: code,
            category: ObservabilityCategory.storage,
          ),
        );
      }
    }
    expect(
      observer.events,
      hasLength(SessionObservabilityService.maxEventsPerSession),
    );
    await SessionObservabilityService(observer).record(event);
    expect(
      observer.events,
      hasLength(SessionObservabilityService.maxEventsPerSession + 1),
    );
  });

  test('safe helper exposes only codes for malformed private JSON', () {
    final session = SessionObservabilityService(observer);
    observeUnexpectedError(
      session,
      const FormatException('private', '{"uid":"private","answers":['),
      operation: ObservabilityOperation.pendingStorage,
      category: ObservabilityCategory.storage,
    );
    expect(
      _payload(observer.events.single),
      'pendingStorage/invalidData/storage/false',
    );
  });
}

String _payload(ObservabilityEvent event) =>
    '${event.operation.name}/${event.code.name}/${event.category.name}/${event.fatal}';

class _Observer implements ObservabilityService {
  final events = <ObservabilityEvent>[];
  Object? failure;
  bool failAsynchronously = false;

  @override
  Future<void> record(ObservabilityEvent event) {
    events.add(event);
    if (failure != null) throw failure!;
    if (failAsynchronously) {
      return Future<void>.error(StateError('secondary-private'));
    }
    return Future<void>.value();
  }
}

class _PrivateError implements Exception {
  @override
  String toString() => throw StateError('Private exception was serialized');
}
