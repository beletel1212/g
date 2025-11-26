import 'package:flutter/services.dart';

/// Service that communicates with Android's BlockedNumberContract.
/// All calls are forwarded to the Android side using MethodChannel.
class BlockedNumbersService {
  /// Channel name used to communicate with Android native code.
  static const MethodChannel _channel =
      MethodChannel('gofer.dialer/blocked_numbers');

  /// Returns the list of currently blocked numbers.
  static Future<List<String>> getBlockedNumbers() async {
    final List<dynamic> result =
        await _channel.invokeMethod('getBlockedNumbers');

    // Convert dynamic list to List<String>
    return result.cast<String>();
  }

  /// Blocks the given phone number via Android's BlockedNumberContract.
  ///
  /// [number] - The phone number to block.
  static Future<bool> blockNumber(String number) async {
    final bool result =
        await _channel.invokeMethod('blockNumber', {"number": number});
    return result;
  }

  /// Unblocks the given phone number.
  ///
  /// [number] - The phone number to unblock.
  static Future<bool> unblockNumber(String number) async {
    final bool result =
        await _channel.invokeMethod('unblockNumber', {"number": number});
    return result;
  }
}
