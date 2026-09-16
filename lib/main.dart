import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'core/system/app_system_ui.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSystemUi.configure();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(YoMeCuidoApp());
}
