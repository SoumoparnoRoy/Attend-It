import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_theme.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerFontLicences();

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

/// The OFL requires its text to travel with the fonts it covers, so the two
/// licence files ship as assets and are read lazily into Flutter's registry
/// rather than being pasted into a source file.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry<String, String> font in const <String, String>{
      'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-OFL.txt',
      'JetBrains Mono': 'assets/fonts/JetBrainsMono-OFL.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks(
        <String>[font.key],
        await rootBundle.loadString(font.value),
      );
    }
  });
}
