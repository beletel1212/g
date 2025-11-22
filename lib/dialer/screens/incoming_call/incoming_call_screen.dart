import 'package:flutter/material.dart';
import 'package:gofer/dialer/services/incoming_call_service.dart';

/// Incoming call UI
/// This screen is shown whenever there is an incoming call.
/// Displays caller info and provides Answer / Reject buttons.
class IncomingCallScreen extends StatelessWidget {
  /// Phone number of the caller
  final String phoneNumber;

  /// Optional caller name resolved from contacts
  final String? callerName;

  /// Constructor requires phone number, callerName is optional
  const IncomingCallScreen({
    super.key,
    required this.phoneNumber,
    this.callerName,
  });

  /// Answer the call using the service
  /// Also closes the screen after answering
  void _onAnswer(BuildContext context) {
    IncomingCallService().answerCall(); // Calls native channel to answer
    Navigator.pop(context); // Close incoming call screen
  }

  /// Reject the call using the service
  /// Also closes the screen after rejecting
  void _onReject(BuildContext context) {
    IncomingCallService().rejectCall(); // Calls native channel to reject
    Navigator.pop(context); // Close incoming call screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Background for incoming call UI
      body: Stack(
        children: [
          /// Centered caller info
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Placeholder avatar
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),

                /// Display caller name or phone number
                Text(
                  callerName ?? phoneNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                /// Small label showing "Incoming call"
                const Text(
                  "Incoming call",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          ),

          /// Answer / Reject buttons at bottom
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                /// Reject button (red)
                FloatingActionButton(
                  heroTag: "reject_btn",
                  backgroundColor: Colors.red,
                  onPressed: () => _onReject(context),
                  child: const Icon(Icons.call_end, size: 32),
                ),

                /// Answer button (green)
                FloatingActionButton(
                  heroTag: "answer_btn",
                  backgroundColor: Colors.green,
                  onPressed: () => _onAnswer(context),
                  child: const Icon(Icons.call, size: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
