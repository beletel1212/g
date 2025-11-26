import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Widget to prompt the user for Notification permission during onboarding.
class NotificationPermissionPrompt extends StatefulWidget {
  const NotificationPermissionPrompt({super.key});

  @override
  State<NotificationPermissionPrompt> createState() =>
      _NotificationPermissionPromptState();
}

class _NotificationPermissionPromptState
    extends State<NotificationPermissionPrompt> {
  /// Tracks whether notification permission is granted.
  bool _isGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// Checks current permission status for notifications.
  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;
    setState(() => _isGranted = status.isGranted);
  }

  /// Requests notification permission when the user taps the button.
  Future<void> _requestPermission() async {
    final result = await Permission.notification.request();
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
              "Notifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isGranted
                  ? "Notification permission granted."
                  : "Allow notifications to receive incoming call alerts and missed call alerts.",
            ),
            const SizedBox(height: 12),
            if (!_isGranted)
              ElevatedButton(
                onPressed: _requestPermission,
                child: const Text("Allow Notifications"),
              ),
          ],
        ),
      ),
    );
  }
}
