
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tile_two/screens/game_screen.dart';
import 'package:tile_two/screens/home_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before doing anything else.
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred screen orientation to portrait mode.
  // This is crucial for a consistent game experience on mobile.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide system UI overlays (like the status bar and navigation bar) for a
  // full-screen, immersive game experience.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/game': (context) => const GameScreen(),
      },
    );
  }
}
