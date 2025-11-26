import 'package:flutter/material.dart';
import 'package:gofer/dialer/services/incoming_call_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // flutter_contacts import
import 'package:flutter/services.dart';
import 'package:gofer/main.dart'; // ADDED: import to access global contactsCache

/// Incoming call UI
/// This screen is shown whenever there is an incoming call.
/// Displays caller info and provides Answer / Reject buttons.
class IncomingCallScreen extends StatefulWidget {
  /// Phone number of the caller
  final String phoneNumber;

  /// Optional caller name resolved from contacts
  final String? callerName;

  /// Optional contact object with avatar/photo
  final Contact? contact;

  /// Constructor requires phone number, callerName and optional contact
  const IncomingCallScreen({
    super.key,
    required this.phoneNumber,
    this.callerName,
    this.contact,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  /// Holds the auto-fetched contact from phone number
  /// If widget.contact is provided, this is ignored.
  Contact? _resolvedContact;

  // -------------------------------------------------------------
  // CHANNEL TO RECEIVE CALL EVENTS FROM ANDROID
  // -------------------------------------------------------------
  static const MethodChannel _callChannel =
      MethodChannel("gofer.dialer/incoming_call");

  @override
  void initState() {
    super.initState();

    /// Only auto-load contact if no contact was passed manually.
    if (widget.contact == null) {
      _loadContactFromNumber();
    }

    // Listen for callEnded from MainActivity.kt
    _callChannel.setMethodCallHandler((call) async {
      if (call.method == "callEnded") {
        if (mounted) {
          Navigator.of(context).pop(); // Auto-dismiss UI
        }
      }
      return null;
    });
  }

  /// Loads a matching contact using the phone number (optimized with global cache)
  Future<void> _loadContactFromNumber() async {
    try {
      // Normalize the number for lookup
      final normalizedNumber = widget.phoneNumber.replaceAll(RegExp(r'\D'), "");

      // Lookup contact in global cache from main.dart
      if (contactsCache.containsKey(normalizedNumber)) {
        setState(() {
          _resolvedContact = contactsCache[normalizedNumber];
        });
      }
    } catch (_) {
      // Silently ignore any errors
    }
  }

  /// Builds the avatar, showing contact photo if available
  Widget _buildAvatar() {
    final Contact? displayContact = widget.contact ?? _resolvedContact;

    // Use contact photo if available
    if (displayContact != null &&
        displayContact.photoOrThumbnail != null &&
        displayContact.photoOrThumbnail!.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: MemoryImage(displayContact.photoOrThumbnail!),
      );
    }

    // Fallback: contact exists but no photo
    if (displayContact != null) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blueGrey.shade300,
        child: Text(
          (displayContact.displayName.isNotEmpty)
              ? displayContact.displayName[0].toUpperCase()
              : "?",
          style: const TextStyle(color: Colors.white, fontSize: 32),
        ),
      );
    }

    // No contact info at all
    return const CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  /// Answer the call using the service
  void _onAnswer(BuildContext context) {
    IncomingCallService().answerCall();
    Navigator.pop(context);
  }

  /// Reject the call using the service
  void _onReject(BuildContext context) {
    IncomingCallService().rejectCall();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final Contact? displayContact = widget.contact ?? _resolvedContact;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Centered caller info
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(),
                const SizedBox(height: 20),
                Text(
                  displayContact?.displayName ??
                      widget.callerName ??
                      widget.phoneNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
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
                FloatingActionButton(
                  heroTag: "reject_btn",
                  backgroundColor: Colors.red,
                  onPressed: () => _onReject(context),
                  child: const Icon(Icons.call_end, size: 32),
                ),
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
