import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gofer/dialer/screens/incoming_call/incoming_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // added for persistent last-call storage
import 'dart:async'; // NEW: required for StreamController

/// Flutter service to listen for incoming calls from Android.
class IncomingCallService {
  /// Android method channel for incoming call actions
  static const MethodChannel _channel =
      MethodChannel('gofer.dialer/incoming_call');

  /// ------------------------------------------------------------
  /// BROADCAST STREAM FOR CALL STATE EVENTS
  /// ------------------------------------------------------------
  /// Allows UI screens (InCallScreen) to listen for "callEnded" events.
  static final StreamController<String> _callEventController =
      StreamController<String>.broadcast();

  /// Public stream for widgets to listen to call events
  static Stream<String> get callEventStream => _callEventController.stream;

  /// Singleton instance
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  /// Set up listener and provide context to navigate
  void initialize(BuildContext context) {
    // Restore last incoming call saved by Android
    _restoreLastIncomingCall(context);

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingCall') {
        final number = call.arguments['number'] as String? ?? '';

        // Save latest incoming call number for restoration
        _saveLastIncomingCall(number);

        // Open IncomingCallScreen for the incoming call
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(phoneNumber: number),
          ),
        );
      }

      // Handle stored incoming call number from Android
      else if (call.method == 'incomingCallStored') {
        final storedNumber =
            await _channel.invokeMethod<String>('getSavedIncomingNumber');

        if (storedNumber != null && storedNumber.isNotEmpty) {
          await _channel.invokeMethod('clearSavedIncomingNumber');

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

      // Receive "callEnded" from Android side
      else if (call.method == 'callEnded') {
        _callEventController.add("callEnded");
      }
    });
  }

  /// Save last incoming number to SharedPreferences (for restoration)
  Future<void> _saveLastIncomingCall(String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('incoming_call_number', number);
  }

  /// Restore last incoming number when Flutter initializes
  Future<void> _restoreLastIncomingCall(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final number = prefs.getString('incoming_call_number');

    if (number != null && number.isNotEmpty) {
      await prefs.remove('incoming_call_number');

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
      await _channel.invokeMethod('answerCall');
    } catch (e) {
      debugPrint('Error answering call: $e');
    }
  }

  /// Call Android to reject the current incoming call
  Future<void> rejectCall() async {
    try {
      await _channel.invokeMethod('rejectCall');
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  /// End an ongoing call using Android TelecomManager
  Future<void> endCall() async {
    try {
      await _channel.invokeMethod('endCall');
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  // ----------------------------------------------------------------------
  // NEW: FETCH CALL LOGS FROM ANDROID SYSTEM DATABASE (F4.1)
  // ----------------------------------------------------------------------
  /// Returns a list of recent call logs from Android system
  /// Each log is a map: {number, type, duration, date, new}
  /// The method calls Android via the same MethodChannel.
  /// `limit` specifies the number of recent logs to fetch (default 50).
  Future<List<Map<String, dynamic>>> getCallLogs({int limit = 50}) async {
    try {
      final List<dynamic>? logs =
          await _channel.invokeMethod('getCallLogs', {'limit': limit});
      if (logs != null) {
        // Convert dynamic list to strongly typed list of maps
        return List<Map<String, dynamic>>.from(logs);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching call logs: $e');
      return [];
    }
  }
}
