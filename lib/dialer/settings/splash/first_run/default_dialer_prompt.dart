import 'package:flutter/material.dart';
import 'package:gofer/dialer/dialer_default/dialer_default_service.dart';

/// UI widget that shows a button for setting the app as default dialer.
class DefaultDialerPrompt extends StatefulWidget {
  const DefaultDialerPrompt({super.key});

  @override
  State<DefaultDialerPrompt> createState() => _DefaultDialerPromptState();
}

class _DefaultDialerPromptState extends State<DefaultDialerPrompt> {
  /// Whether the app is currently the default dialer.
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _checkDefault();
  }

  /// Checks if the app is already the default dialer.
  Future<void> _checkDefault() async {
    final status = await DefaultDialerService.isDefaultDialer();
          if (mounted) {
            setState(() => _isDefault = status);
          }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade50,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Default Dialer",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isDefault
                  ? "This app is already set as the default phone app."
                  : "Set this app as your default dialer for full functionality.",
            ),
            const SizedBox(height: 12),

            if (!_isDefault)
              ElevatedButton(
                onPressed: () {
                  DefaultDialerService.requestSetDefaultDialer();
                },
                child: const Text("Set as default dialer"),
              ),
          ],
        ),
      ),
    );
  }
}
