import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'error_observation.dart';
import 'observability_service.dart';

final class GlobalErrorCapture {
  GlobalErrorCapture({required ObservabilityService observabilityService})
    : _observability = SessionObservabilityService(observabilityService);

  final ObservabilityService _observability;
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;
  bool _installed = false;

  void install() {
    if (_installed) return;
    _previousFlutterHandler = FlutterError.onError;
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    FlutterError.onError = _handleFlutterError;
    PlatformDispatcher.instance.onError = _handlePlatformError;
    _installed = true;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    observeUnexpectedError(
      _observability,
      details.exception,
      operation: ObservabilityOperation.framework,
      category: ObservabilityCategory.framework,
    );
    // Keep Flutter's standard console diagnostics and development behavior.
    (_previousFlutterHandler ?? FlutterError.presentError)(details);
  }

  bool _handlePlatformError(Object error, StackTrace stack) {
    observeUnexpectedError(
      _observability,
      error,
      operation: ObservabilityOperation.asynchronousTask,
      category: ObservabilityCategory.framework,
      fatal: true,
    );
    // Recording an event does not mean an uncaught error has been handled.
    return _previousPlatformHandler?.call(error, stack) ?? false;
  }

  void restore() {
    if (!_installed) return;
    if (FlutterError.onError == _handleFlutterError) {
      FlutterError.onError = _previousFlutterHandler;
    }
    if (PlatformDispatcher.instance.onError == _handlePlatformError) {
      PlatformDispatcher.instance.onError = _previousPlatformHandler;
    }
    _installed = false;
  }
}
