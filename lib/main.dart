import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/system/app_system_ui.dart';
import 'firebase_options.dart';
import 'shared/services/crashlytics_observability_service.dart';
import 'shared/services/crashlytics_qa_controller.dart';
import 'shared/services/error_observation.dart';
import 'shared/services/global_error_capture.dart';
import 'shared/services/observability_service.dart';

Future<void> main() async {
  final observabilityService = SessionObservabilityService(
    const NoOpObservabilityService(),
  );
  var operation = ObservabilityOperation.bootstrap;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await AppSystemUi.configure();
    operation = ObservabilityOperation.initializeFirebase;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    operation = ObservabilityOperation.initializeAppCheck;
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    operation = ObservabilityOperation.initializeObservability;
    if (crashlyticsQaEnabled) {
      final qa = CrashlyticsQaController(
        crashlytics: FirebaseCrashlytics.instance,
        preferences: SharedPreferencesAsync(),
        isSignedOut: () => FirebaseAuth.instance.currentUser == null,
      );
      await qa.initialize();
      qa.registerDeveloperCommand();
    } else {
      await initializeDisabledObservability(
        observabilityService: observabilityService,
      );
    }
  } catch (error) {
    observeUnexpectedError(
      observabilityService,
      error,
      operation: operation,
      category: ObservabilityCategory.initialization,
      fatal: true,
    );
    rethrow;
  }

  GlobalErrorCapture(observabilityService: observabilityService).install();
  runApp(YoMeCuidoApp(observabilityService: observabilityService));
}
