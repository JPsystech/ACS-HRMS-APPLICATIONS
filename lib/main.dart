import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/config/env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  Env.logConfig();

  // Ensure Firebase is initialized before the app starts.
  // This keeps FcmService.init() idempotent and release-safe.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Intentionally use print (release-safe).
    print('❌ Firebase.initializeApp() failed: $e');
  }

  runApp(const ProviderScope(child: HrmsApp()));
}
