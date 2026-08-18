import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_theme.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set the chrome dark before the first frame so launch never flashes light.
  // Once MaterialApp is up its AppBarTheme takes over and follows whichever
  // theme the user chose.
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.overlayStyleFor(AppPalette.dark),
  );
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Notification setup is best-effort — a failure here must never block
  // launch, so the service swallows and logs its own errors.
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: ZeoliteApp()));
}
