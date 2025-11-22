import 'dart:io';
import 'package:flutter/services.dart';

/// Platform channel to communicate with Android native code.
const platform = MethodChannel('dialer.default.channel');

/// Service responsible for checking and requesting default dialer role.
class DefaultDialerService {
  /// Checks if the app is already set as the default dialer.
  static Future<bool> isDefaultDialer() async {
    if (!Platform.isAndroid) return false;
    return await platform.invokeMethod<bool>('isDefaultDialer') ?? false;
  }

  /// Requests Android system dialog to set this app as default dialer.
  static Future<void> requestSetDefaultDialer() async {
    if (!Platform.isAndroid) return;
    await platform.invokeMethod('requestDefaultDialer');
  }
}
