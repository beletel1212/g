import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gofer/dialer/screens/incoming_call/incoming_call_screen.dart';

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
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingCall') {
        final number = call.arguments['number'] as String? ?? '';

        // Open IncomingCallScreen for the incoming call
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(phoneNumber: number),
          ),
        );
      }
    });
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
