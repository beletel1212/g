import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gofer/dialer/screens/incoming_call/incoming_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // added for persistent last-call storage

/// Flutter service to listen for incoming calls from Android.
class IncomingCallService {
  /// Android method channel for incoming call actions
  static const MethodChannel _channel =
      MethodChannel('gofer.dialer/incoming_call');

  /// Singleton instance
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  /// Set up listener and provide context to navigate
  /// Opens IncomingCallScreen when an incoming call is detected from Android
  void initialize(BuildContext context) {
    // NEW: Try to restore last incoming call saved by Android (Option A)
    _restoreLastIncomingCall(context);

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingCall') {
        final number = call.arguments['number'] as String? ?? '';

        // NEW: Save latest incoming call number
        // This allows the app to show the incoming call screen
        // even if Android sent the event before Flutter was fully ready.
        _saveLastIncomingCall(number);

        // Open IncomingCallScreen for the incoming call
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(phoneNumber: number),
          ),
        );
      }

      // NEW: Handle Flutter request to check stored number from Android
      else if (call.method == 'incomingCallStored') {
        // Ask Android for the saved number
        final storedNumber =
            await _channel.invokeMethod<String>('getSavedIncomingNumber');

        if (storedNumber != null && storedNumber.isNotEmpty) {
          // Clear immediately so it doesn't show again
          await _channel.invokeMethod('clearSavedIncomingNumber');

          // Show IncomingCallScreen for stored number
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IncomingCallScreen(phoneNumber: storedNumber),
              ),
            );
          });
        }
      }
    });
  }

  /// NEW: Save last incoming number to SharedPreferences (for restoration)
  Future<void> _saveLastIncomingCall(String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('incoming_call_number', number);
  }

  /// NEW: Restore last incoming number when Flutter initializes
  Future<void> _restoreLastIncomingCall(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final number = prefs.getString('incoming_call_number');

    if (number != null && number.isNotEmpty) {
      // Clear immediately to avoid repeating
      await prefs.remove('incoming_call_number');

      // Show incoming call screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(phoneNumber: number),
          ),
        );
      });
    }
  }

  /// Call Android to answer the current incoming call
  Future<void> answerCall() async {
    try {
      await _channel.invokeMethod('answerCall'); // updated to match MainActivity
    } catch (e) {
      debugPrint('Error answering call: $e');
    }
  }

  /// Call Android to reject the current incoming call
  Future<void> rejectCall() async {
    try {
      await _channel.invokeMethod('rejectCall'); // updated to match MainActivity
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }
}
