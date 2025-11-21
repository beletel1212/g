import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gofer/dialer/settings/splash/first_run/default_dialer_prompt.dart';
import 'package:gofer/dialer/screens/dialer_home_screen.dart';

// Import the contacts permission prompt
import 'package:gofer/dialer/settings/splash/first_run/contacts_permission_prompt.dart';
// Import the notification permission prompt
import 'package:gofer/dialer/settings/splash/first_run/notification_permission_prompt.dart';

/// First-run onboarding screen.
/// Shown only the very first time the user opens the app.
class FirstRunScreen extends StatelessWidget {
  const FirstRunScreen({super.key});

  /// Marks onboarding as complete and navigates to home screen.
  Future<void> _finishOnboarding(BuildContext context) async {
    // SharedPreferences instance to store persistent flag
    final prefs = await SharedPreferences.getInstance();

    // Save that onboarding has been completed
    await prefs.setBool('hasSeenOnboarding', true);

    // Navigate to main dialer home screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DialerHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        /// Title of onboarding screen
        title: const Text("Welcome"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// Step 1 – ask user to set default dialer
          const DefaultDialerPrompt(),

          const SizedBox(height: 24),

          /// Step 2 – ask user to grant contacts permission
          const ContactsPermissionPrompt(),

          const SizedBox(height: 24),

          /// Step 3 – ask user to grant notification permission
          const NotificationPermissionPrompt(),

          const SizedBox(height: 24),

          /// "Continue" button to complete onboarding
          ElevatedButton(
            onPressed: () => _finishOnboarding(context),
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }
}
