import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gofer/dialer/screens/dialer_home_screen.dart';
import 'package:gofer/dialer/screens/first_run/first_run_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check first run BEFORE starting the app
  final isFirstRun = await _checkFirstRun();

  runApp(
    ProviderScope(
      child: DialerApp(isFirstRun: isFirstRun),
    ),
  );
}

/// Determines whether this is the app's first launch.
Future<bool> _checkFirstRun() async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool('hasSeenOnboarding') ?? false;
  return !seen; // If never seen onboarding → first run.
}

class DialerApp extends StatelessWidget {
  final bool isFirstRun;

  const DialerApp({super.key, required this.isFirstRun});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dialer App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        textTheme: Typography.material2021().black,
      ),

      // 👇 THIS IS THE ONLY REAL CHANGE: show onboarding before home
      home: isFirstRun
          ? const FirstRunScreen()       // contains DefaultDialerPrompt
          : const DialerHomeScreen(),    // your normal UI
    );
  }
}
