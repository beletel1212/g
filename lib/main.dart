import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

//  flutter_contacts for global preloading- i.e caching for faster loading
import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:gofer/dialer/screens/dialer_home_screen.dart';
import 'package:gofer/dialer/settings/splash/first_run/first_run_screen.dart';

/// GLOBAL CONTACT CACHE: phone number → Contact
/// Normalized numbers are keys for fast lookup.
final Map<String, Contact> contactsCache = {};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check first run BEFORE starting the app
  final isFirstRun = await _checkFirstRun();

  // ADDED: preload contacts into global cache
  await _preloadContacts();

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

/// Preloads all phone contacts into a global map for fast lookup.
/// Normalizes numbers and keeps a map: number → Contact.
Future<void> _preloadContacts() async {
  try {
    // Request permission for contacts
    if (!await FlutterContacts.requestPermission()) return;

    // Fetch all contacts with phone numbers
    final List<Contact> allContacts =
        await FlutterContacts.getContacts(withProperties: true);

    for (var contact in allContacts) {
      for (var phone in contact.phones) {
        final normalized = phone.number.replaceAll(RegExp(r'\D'), "");
        if (normalized.isNotEmpty) {
          contactsCache[normalized] = contact;
        }
      }
    }
  } catch (e) {
    // Silently fail if permissions denied or error occurs
    debugPrint('Contacts preload failed: $e');
  }
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
