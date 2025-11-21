import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Widget to prompt the user for Contacts permission during onboarding.
class ContactsPermissionPrompt extends StatefulWidget {
  const ContactsPermissionPrompt({super.key});

  @override
  State<ContactsPermissionPrompt> createState() =>
      _ContactsPermissionPromptState();
}

class _ContactsPermissionPromptState extends State<ContactsPermissionPrompt> {
  /// Tracks whether contacts permission is granted.
  bool _isGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// Checks current permission status for contacts.
  Future<void> _checkPermission() async {
    final status = await Permission.contacts.status;
    setState(() => _isGranted = status.isGranted);
  }

  /// Requests contacts permission when the user taps the button.
  Future<void> _requestPermission() async {
    final result = await Permission.contacts.request();
    setState(() => _isGranted = result.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Contacts Access",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isGranted
                  ? "Contacts permission granted."
                  : "Allow access to your contacts to show names and pictures.",
            ),
            const SizedBox(height: 12),
            if (!_isGranted)
              ElevatedButton(
                onPressed: _requestPermission,
                child: const Text("Allow Contacts"),
              ),
          ],
        ),
      ),
    );
  }
}
