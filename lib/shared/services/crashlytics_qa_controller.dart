import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crashlytics_observability_service.dart';

const crashlyticsQaEnabled =
    kDebugMode &&
    bool.fromEnvironment('YMC_CRASHLYTICS_QA', defaultValue: false);

enum CrashlyticsQaPhase { idle, attempted, recorded, submitted, restored }

// Only a phase is persisted on the isolated QA installation, never event data.
final class CrashlyticsQaController {
  CrashlyticsQaController({
    required FirebaseCrashlytics crashlytics,
    required SharedPreferencesAsync preferences,
    required bool Function() isSignedOut,
    bool qaFlagEnabled = const bool.fromEnvironment('YMC_CRASHLYTICS_QA'),
  }) : _client = crashlytics,
       _preferences = preferences,
       _isSignedOut = isSignedOut,
       _qaFlagEnabled = qaFlagEnabled;

  static const confirmation = 'YMC_CRASHLYTICS_QA_NONFATAL';
  static const extensionName = 'ext.yomecuido.crashlyticsQa';
  static const _phaseKey = 'crashlytics_qa_phase_v1';
  static const _deadline = Duration(seconds: 15);
  final FirebaseCrashlytics _client;
  final SharedPreferencesAsync _preferences;
  final bool Function() _isSignedOut;
  final bool _qaFlagEnabled;
  bool _busy = false;
  bool _emittedThisLaunch = false;
  bool _registered = false;

  void _requireAllowed() {
    if (!kDebugMode || !_qaFlagEnabled) throw StateError('QA disabled.');
  }

  void _requireConfirmation(bool confirmed, bool isolated) {
    _requireAllowed();
    if (!confirmed || !isolated || !_isSignedOut()) {
      throw StateError('Isolated signed-out QA confirmation required.');
    }
    if (_busy) throw StateError('QA action already running.');
  }

  Future<CrashlyticsQaPhase> get phase async {
    _requireAllowed();
    final raw = await _preferences.getString(_phaseKey);
    if (raw == null) return CrashlyticsQaPhase.idle;
    return CrashlyticsQaPhase.values.firstWhere(
      (phase) => phase.name == raw,
      orElse: () => throw StateError('Invalid QA phase.'),
    );
  }

  Future<void> _savePhase(CrashlyticsQaPhase phase) =>
      _preferences.setString(_phaseKey, phase.name);

  Future<void> initialize() async {
    _requireAllowed();
    await _client.setCrashlyticsCollectionEnabled(false);
    if (_client.isCrashlyticsCollectionEnabled) {
      throw StateError('QA collection could not be disabled.');
    }
    // Do not delete the previous QA session before its explicit submission.
  }

  Future<void> emit({required bool confirmed, required bool isolated}) async {
    _requireConfirmation(confirmed, isolated);
    _busy = true;
    try {
      if (await phase != CrashlyticsQaPhase.idle ||
          _client.isCrashlyticsCollectionEnabled ||
          await _client.checkForUnsentReports()) {
        throw StateError('QA already attempted or old reports exist.');
      }
      // Claim before recording: an interrupted/ambiguous call must not emit twice.
      await _savePhase(CrashlyticsQaPhase.attempted);
      _emittedThisLaunch = true;
      try {
        await _client.setCrashlyticsCollectionEnabled(true).timeout(_deadline);
        final recorded = await CrashlyticsObservabilityService(
          crashlytics: _client,
          reportingEnabled: true,
        ).recordQaNonFatal().timeout(_deadline);
        if (!recorded) throw StateError('QA recording failed.');
        await _savePhase(CrashlyticsQaPhase.recorded);
      } finally {
        await _client.setCrashlyticsCollectionEnabled(false).timeout(_deadline);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> submit({required bool confirmed, required bool isolated}) async {
    _requireConfirmation(confirmed, isolated);
    _busy = true;
    try {
      if (_emittedThisLaunch || await phase != CrashlyticsQaPhase.recorded) {
        throw StateError('Restart the recorded QA session before submission.');
      }
      await _client.setCrashlyticsCollectionEnabled(false).timeout(_deadline);
      if (_client.isCrashlyticsCollectionEnabled ||
          !await _client.checkForUnsentReports()) {
        throw StateError('No closed QA report available for submission.');
      }
      await _client.sendUnsentReports().timeout(_deadline);
      await _savePhase(CrashlyticsQaPhase.submitted);
      // SDK acceptance is not proof of server delivery or Console reception.
    } finally {
      try {
        await _client.setCrashlyticsCollectionEnabled(false).timeout(_deadline);
      } finally {
        _busy = false;
      }
    }
  }

  Future<void> restore({required bool receptionConfirmed}) async {
    _requireAllowed();
    if (!receptionConfirmed || _busy) {
      throw StateError('Console confirmation required before cleanup.');
    }
    _busy = true;
    try {
      if (await phase != CrashlyticsQaPhase.submitted) {
        throw StateError('QA has not been submitted.');
      }
      await _client.setCrashlyticsCollectionEnabled(false).timeout(_deadline);
      if (_client.isCrashlyticsCollectionEnabled) {
        throw StateError('QA collection could not be disabled.');
      }
      await _client.deleteUnsentReports().timeout(_deadline);
      await _savePhase(CrashlyticsQaPhase.restored);
    } finally {
      _busy = false;
    }
  }

  void registerDeveloperCommand() {
    _requireAllowed();
    if (_registered) return;
    _registered = true;
    developer.registerExtension(extensionName, (_, parameters) async {
      try {
        final confirmed = parameters['confirm'] == confirmation;
        final isolated = parameters['isolated'] == 'true';
        switch (parameters['action']) {
          case 'emit':
            await emit(confirmed: confirmed, isolated: isolated);
          case 'submit':
            await submit(confirmed: confirmed, isolated: isolated);
          case 'restore':
            await restore(
              receptionConfirmed:
                  parameters['consoleReceived'] == 'true' && confirmed,
            );
          case 'status':
            _requireAllowed();
          default:
            throw StateError('Unknown QA action.');
        }
        return developer.ServiceExtensionResponse.result(
          jsonEncode({
            'phase': (await phase).name,
            'collectionEnabled': _client.isCrashlyticsCollectionEnabled,
            'normalService': 'NoOp',
            'signedOut': _isSignedOut(),
          }),
        );
      } catch (_) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'QA_ACTION_REJECTED',
        );
      }
    });
  }
}
