
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tile_two/game/rewarded_ads_service.dart';
import 'package:tile_two/l10n/app_i18n.dart';
import 'package:tile_two/screens/game_screen.dart';
import 'package:tile_two/screens/home_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before doing anything else.
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();

  // Set preferred screen orientation to portrait mode.
  // This is crucial for a consistent game experience on mobile.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide system UI overlays (like the status bar and navigation bar) for a
  // full-screen, immersive game experience.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  unawaited(RewardedAdsService.instance.syncAdPressureConfig());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: AppLanguageController.instance.locale,
          supportedLocales: AppI18n.supportedLocales,
          localizationsDelegates: const [
            AppI18n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const HomeScreen(),
            '/game': (context) => const GameScreen(),
          },
        );
      },
    );
  }
}
