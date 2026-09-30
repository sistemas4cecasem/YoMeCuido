import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import 'observability_service.dart';

// Classify locally; the exception and its stack never enter the event contract.
ObservabilityErrorCode? classifyUnexpectedError(
  Object error, {
  ObservabilityErrorCode fallback = ObservabilityErrorCode.unexpected,
}) {
  if (error is TimeoutException) return null;
  if (error is FirebaseException) {
    return classifyFirebaseErrorCode(error.code);
  }
  if (error is FormatException || error is TypeError) {
    return ObservabilityErrorCode.invalidData;
  }
  if (error is StateError || error is ArgumentError) {
    return ObservabilityErrorCode.invariantViolation;
  }
  return fallback;
}

ObservabilityErrorCode? classifyFirebaseErrorCode(String? code) =>
    switch (code) {
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' ||
      'cancelled' ||
      'unauthenticated' ||
      'invalid-credential' ||
      'wrong-password' ||
      'requires-recent-login' ||
      'user-token-expired' ||
      'invalid-email' ||
      'email-already-in-use' ||
      'weak-password' ||
      'user-not-found' ||
      'user-disabled' ||
      'too-many-requests' => null,
      'permission-denied' => ObservabilityErrorCode.permissionDenied,
      'data-loss' => ObservabilityErrorCode.invalidData,
      _ => ObservabilityErrorCode.unexpected,
    };

void observeUnexpectedError(
  ObservabilityService service,
  Object error, {
  required ObservabilityOperation operation,
  required ObservabilityCategory category,
  ObservabilityErrorCode fallback = ObservabilityErrorCode.unexpected,
  bool fatal = false,
}) {
  final code = classifyUnexpectedError(error, fallback: fallback);
  if (code == null) return;
  unawaited(
    SessionObservabilityService(service).record(
      ObservabilityEvent(
        operation: operation,
        code: code,
        category: category,
        fatal: fatal,
      ),
    ),
  );
}
