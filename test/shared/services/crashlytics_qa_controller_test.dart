import 'dart:async';

import 'package:demo_yomecuido/shared/services/crashlytics_qa_controller.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late SharedPreferencesAsync preferences;
  late CrashlyticsQaController qa;

  setUp(() {
    final original = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
    preferences = SharedPreferencesAsync();
    client = _Client();
    qa = _controller(client, preferences);
  });

  test('QA is off by default; initialize never enables or emits', () async {
    expect(crashlyticsQaEnabled, isFalse);
    await qa.initialize();
    expect(client.calls, ['collection:false']);
    expect(client.reports, isEmpty);
    expect(await qa.phase, CrashlyticsQaPhase.idle);
  });

  test(
    'without an explicit compile flag all QA actions are rejected',
    () async {
      final disabled = CrashlyticsQaController(
        crashlytics: client,
        preferences: preferences,
        isSignedOut: () => true,
        qaFlagEnabled: false,
      );
      await expectLater(disabled.initialize(), throwsStateError);
      await expectLater(
        disabled.emit(confirmed: true, isolated: true),
        throwsStateError,
      );
      await expectLater(
        disabled.submit(confirmed: true, isolated: true),
        throwsStateError,
      );
      await expectLater(
        disabled.restore(receptionConfirmed: true),
        throwsStateError,
      );
      expect(client.calls, isEmpty);
    },
  );

  test(
    'explicit confirmation and isolated installation are both required',
    () async {
      await expectLater(
        qa.emit(confirmed: false, isolated: true),
        throwsStateError,
      );
      await expectLater(
        qa.emit(confirmed: true, isolated: false),
        throwsStateError,
      );
      expect(client.calls, isEmpty);
    },
  );

  test('an authenticated QA session cannot emit', () async {
    final signedIn = _controller(client, preferences, signedOut: false);
    await expectLater(
      signedIn.emit(confirmed: true, isolated: true),
      throwsStateError,
    );
    expect(client.calls, isEmpty);
    expect(client.reports, isEmpty);
  });

  test('old reports block activation and are not deleted', () async {
    client.pending = true;
    await qa.initialize();
    await expectLater(
      qa.emit(confirmed: true, isolated: true),
      throwsStateError,
    );
    expect(client.calls, ['collection:false', 'check']);
    expect(client.pending, isTrue);
    expect(await qa.phase, CrashlyticsQaPhase.idle);
  });

  test(
    'one fixed nonfatal uses synthetic stack and always disables afterward',
    () async {
      await qa.initialize();
      await qa.emit(confirmed: true, isolated: true);
      expect(client.calls, [
        'collection:false',
        'check',
        'collection:true',
        'record',
        'collection:false',
      ]);
      final report = client.reports.single;
      expect(report.message, 'YMC_CRASHLYTICS_QA_NONFATAL');
      expect(report.stack, startsWith('#0      YoMeCuidoDiagnostic.record'));
      expect(report.stack, isNot(contains('crashlytics_qa_controller_test')));
      expect(report.fatal, isFalse);
      expect(report.printDetails, isFalse);
      expect(report.reason, isNull);
      expect(report.information, isEmpty);
      expect(client.enabled, isFalse);
      expect(await qa.phase, CrashlyticsQaPhase.recorded);
      await expectLater(
        qa.emit(confirmed: true, isolated: true),
        throwsStateError,
      );
      final restarted = _controller(client, preferences);
      await expectLater(
        restarted.emit(confirmed: true, isolated: true),
        throwsStateError,
      );
      expect(client.reports, hasLength(1));
    },
  );

  test(
    'SDK record failure disables collection and never permits a retry emission',
    () async {
      client.failRecord = true;
      await expectLater(
        qa.emit(confirmed: true, isolated: true),
        throwsStateError,
      );
      expect(client.enabled, isFalse);
      expect(await qa.phase, CrashlyticsQaPhase.attempted);
      client.failRecord = false;
      await expectLater(
        _controller(client, preferences).emit(confirmed: true, isolated: true),
        throwsStateError,
      );
      expect(client.reports, isEmpty);
    },
  );

  test('concurrent developer requests cannot emit twice', () async {
    client.recordGate = Completer<void>();
    final first = qa.emit(confirmed: true, isolated: true);
    for (var tick = 0; tick < 10; tick++) {
      await Future<void>.delayed(Duration.zero);
    }
    await expectLater(
      qa.emit(confirmed: true, isolated: true),
      throwsStateError,
    );
    client.recordGate!.complete();
    await first;
    expect(client.reports, hasLength(1));
    expect(client.enabled, isFalse);
  });

  test(
    'submission requires a restart and never automatically enables collection',
    () async {
      await qa.emit(confirmed: true, isolated: true);
      await expectLater(
        qa.submit(confirmed: true, isolated: true),
        throwsStateError,
      );
      client.calls.clear();
      final restarted = _controller(client, preferences);
      await restarted.initialize();
      expect(client.calls, ['collection:false']);
      await restarted.submit(confirmed: true, isolated: true);
      expect(client.calls, [
        'collection:false',
        'collection:false',
        'check',
        'send',
        'collection:false',
      ]);
      expect(await restarted.phase, CrashlyticsQaPhase.submitted);
      expect(client.enabled, isFalse);
      expect(client.reports, hasLength(1));
      await expectLater(
        restarted.submit(confirmed: true, isolated: true),
        throwsStateError,
      );
    },
  );

  test(
    'submission failure leaves collection off and preserves pending reports',
    () async {
      await qa.emit(confirmed: true, isolated: true);
      client.failSend = true;
      final restarted = _controller(client, preferences);
      await expectLater(
        restarted.submit(confirmed: true, isolated: true),
        throwsStateError,
      );
      expect(client.enabled, isFalse);
      expect(client.pending, isTrue);
      expect(await restarted.phase, CrashlyticsQaPhase.recorded);
      expect(client.calls, isNot(contains('delete')));
    },
  );

  test(
    'cleanup is impossible before submission and Console confirmation',
    () async {
      await expectLater(qa.restore(receptionConfirmed: true), throwsStateError);
      await qa.emit(confirmed: true, isolated: true);
      final restarted = _controller(client, preferences);
      await expectLater(
        restarted.restore(receptionConfirmed: true),
        throwsStateError,
      );
      await restarted.submit(confirmed: true, isolated: true);
      await expectLater(
        restarted.restore(receptionConfirmed: false),
        throwsStateError,
      );
      expect(client.calls, isNot(contains('delete')));
      await restarted.restore(receptionConfirmed: true);
      expect(await restarted.phase, CrashlyticsQaPhase.restored);
      expect(client.calls.sublist(client.calls.length - 2), [
        'collection:false',
        'delete',
      ]);
      expect(client.enabled, isFalse);
      expect(client.reports, hasLength(1));
    },
  );

  test(
    'corrupt QA marker blocks emission instead of resetting the one-shot',
    () async {
      await preferences.setString(
        'crashlytics_qa_phase_v1',
        'private-corruption',
      );
      await expectLater(
        qa.emit(confirmed: true, isolated: true),
        throwsStateError,
      );
      expect(client.calls, isEmpty);
      expect(client.reports, isEmpty);
    },
  );
}

CrashlyticsQaController _controller(
  _Client client,
  SharedPreferencesAsync preferences, {
  bool signedOut = true,
}) => CrashlyticsQaController(
  crashlytics: client,
  preferences: preferences,
  isSignedOut: () => signedOut,
  qaFlagEnabled: true,
);

class _Client implements FirebaseCrashlytics {
  bool enabled = false;
  bool pending = false;
  bool failRecord = false;
  bool failSend = false;
  Completer<void>? recordGate;
  final calls = <String>[];
  final reports = <_Report>[];

  @override
  bool get isCrashlyticsCollectionEnabled => enabled;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool value) async {
    calls.add('collection:$value');
    enabled = value;
  }

  @override
  Future<bool> checkForUnsentReports() async {
    calls.add('check');
    return pending;
  }

  @override
  Future<void> sendUnsentReports() async {
    calls.add('send');
    if (failSend) throw StateError('private-send-error');
    pending = false;
  }

  @override
  Future<void> deleteUnsentReports() async {
    calls.add('delete');
    pending = false;
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
    calls.add('record');
    await recordGate?.future;
    if (failRecord) throw StateError('private-record-error');
    reports.add(
      _Report(
        exception.toString(),
        stack.toString(),
        fatal,
        reason,
        information.toList(),
        printDetails,
      ),
    );
    pending = true;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected SDK call.');
}

class _Report {
  _Report(
    this.message,
    this.stack,
    this.fatal,
    this.reason,
    this.information,
    this.printDetails,
  );
  final String message;
  final String stack;
  final bool fatal;
  final Object? reason;
  final List<Object> information;
  final bool? printDetails;
}
