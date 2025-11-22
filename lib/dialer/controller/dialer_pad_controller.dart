//import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:url_launcher/url_launcher.dart';

/// State class for the Dialer Pad
class DialerPadState {
  /// Currently entered number
  final String enteredNumber;

  /// List of last dialed numbers (call history)
  final List<String> callHistory;

  DialerPadState({this.enteredNumber = '', this.callHistory = const []});

  /// CopyWith method for immutability
  DialerPadState copyWith({String? enteredNumber, List<String>? callHistory}) {
    return DialerPadState(
      enteredNumber: enteredNumber ?? this.enteredNumber,
      callHistory: callHistory ?? this.callHistory,
    );
  }
}

/// StateNotifier to manage the dialer pad
class DialerPadController extends StateNotifier<DialerPadState> {
  DialerPadController() : super(DialerPadState());

  /// Add a digit or symbol to the entered number
  void addDigit(String digit) {
    state = state.copyWith(enteredNumber: state.enteredNumber + digit);
  }

  /// Delete the last digit
  void deleteDigit() {
    if (state.enteredNumber.isNotEmpty) {
      state = state.copyWith(
        enteredNumber:
            state.enteredNumber.substring(0, state.enteredNumber.length - 1),
      );
    }
  }

  /// Clear the entire entered number (long press delete)
  void clearNumber() {
    state = state.copyWith(enteredNumber: '');
  }

  /// Basic phone number validation: digits, * and #
  bool _isValidNumber(String number) {
    final validPattern = RegExp(r'^[0-9*#]+$');
    return number.isNotEmpty && validPattern.hasMatch(number);
  }

  /// Place a call using the phone dialer
  /// Shows SnackBars for errors and invalid numbers
  /// Accepts an optional number parameter
  Future<void> placeCall(BuildContext context, {String? number}) async {
    // Use passed number or fallback to enteredNumber
    final callNumber = number ?? state.enteredNumber;

    // Validate number before calling
    if (!_isValidNumber(callNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }

    final Uri telUri = Uri(scheme: 'tel', path: callNumber);

    try {
      if (await canLaunchUrl(telUri)) {
        // Launch the phone dialer
        await launchUrl(telUri);

        // Add to call history after a successful attempt
        final updatedHistory = [callNumber, ...state.callHistory];
        state = state.copyWith(enteredNumber: '', callHistory: updatedHistory);
      } else {
        // Cannot launch dialer
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot launch dialer for $callNumber')),
        );
      }
    } catch (e) {
      // Error launching dialer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching dialer: $e')),
      );
    }
  }
}

/// Riverpod provider for the Dialer Pad Controller
final dialerPadControllerProvider =
    StateNotifierProvider<DialerPadController, DialerPadState>((ref) {
  return DialerPadController();
});
