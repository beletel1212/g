import 'dart:async';
import 'package:flutter/material.dart';
// ✅ ADD flutter_contacts
import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:gofer/dialer/services/incoming_call_service.dart';

/// In-Call Screen
/// ---------------------------------------------------------
/// This UI appears immediately after the user answers a call.
/// It behaves like all standard dialer apps:
///   - Shows caller name or number
///   - Shows call duration timer
///   - Provides controls (mute, speaker, end call)
///   - Automatically closes when call ends (handled externally)
///
/// The screen only handles UI + timer. Ending the call invokes
/// IncomingCallService().endCall() which triggers the native
/// telecom API.
/// ---------------------------------------------------------
class InCallScreen extends StatefulWidget {
  /// Caller phone number
  final String phoneNumber;

  /// Caller name (if found in contacts)
  final String? callerName;

  /// Full contact (for avatar)
  final Contact? contact;

  const InCallScreen({
    super.key,
    required this.phoneNumber,
    this.callerName,
    this.contact,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  /// Timer that updates every second to display call duration
  Timer? _timer;

  /// Call duration counter in seconds
  int _elapsedSeconds = 0;

  /// Subscription to call-end events from native side
  StreamSubscription? _callEndedSubscription;

  @override
  void initState() {
    super.initState();

    /// Start call duration timer immediately after arriving
    /// on the in-call screen.
    _startTimer();

    /// ---------------------------------------------------------
    /// LISTEN FOR CALL END EVENT FROM NATIVE SIDE
    /// ---------------------------------------------------------
    _callEndedSubscription = IncomingCallService.callEventStream.listen((event) {
      if (event == "callEnded") {
        _timer?.cancel();
        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Prevent timer leaks
    _callEndedSubscription?.cancel(); // Cancel subscription
    super.dispose();
  }

  /// Starts a 1-second periodic timer that increments
  /// _elapsedSeconds and updates the UI.
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  /// Converts seconds to a formatted timer string
  /// Example: 0 → "00:00", 62 → "01:02"
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  /// Build avatar (photo → initial → generic icon)
  Widget _buildAvatar() {
    final Contact? contact = widget.contact;

    // Use flutter_contacts photo if available
    if (contact != null && contact.photo != null && contact.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 55,
        backgroundImage: MemoryImage(contact.photo!),
      );
    }

    // Contact exists but no photo, use first letter
    if (contact != null) {
      final initial = contact.displayName.isNotEmpty
          ? contact.displayName[0].toUpperCase()
          : "?";

      return CircleAvatar(
        radius: 55,
        backgroundColor: Colors.blueGrey.shade300,
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 30),
        ),
      );
    }

    // No contact info at all
    return const CircleAvatar(
      radius: 55,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, size: 55, color: Colors.white),
    );
  }

  /// Ends the call and closes the screen
  void _onEndCall() {
    IncomingCallService().endCall();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar(),
            const SizedBox(height: 20),

            /// Caller name or phone number
            Text(
              widget.callerName ?? widget.phoneNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            /// Call duration timer
            Text(
              _formatDuration(_elapsedSeconds),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 40),

            /// Call controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                /// Mute button (UI only)
                Column(
                  children: const [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.mic_off, color: Colors.white, size: 30),
                    ),
                    SizedBox(height: 8),
                    Text("Mute", style: TextStyle(color: Colors.white)),
                  ],
                ),

                /// End call button
                GestureDetector(
                  onTap: _onEndCall,
                  child: const CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                ),

                /// Speaker button (UI only)
                Column(
                  children: const [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.volume_up, color: Colors.white, size: 30),
                    ),
                    SizedBox(height: 8),
                    Text("Speaker", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
