import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/blocked_number.dart';

/// Repository responsible for saving / removing blocked numbers
/// Uses SharedPreferences for simple local storage
class BlockedNumbersRepository {
  static const String _storageKey = 'blocked_numbers';

  /// Load all blocked numbers from storage
  Future<List<BlockedNumber>> loadBlockedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) return [];

    final List decoded = jsonDecode(jsonString);

    return decoded.map((e) {
      return BlockedNumber(
        number: e['number'],
        blockedAt: DateTime.parse(e['blockedAt']),
      );
    }).toList();
  }

  /// Save updated blocked list
  Future<void> saveBlockedNumbers(List<BlockedNumber> list) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      list.map((e) => {
        'number': e.number,
        'blockedAt': e.blockedAt.toIso8601String(),
      }).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  /// Add a number to the blocked list
  Future<void> blockNumber(String number) async {
    final current = await loadBlockedNumbers();

    current.add(
      BlockedNumber(
        number: number,
        blockedAt: DateTime.now(),
      ),
    );

    await saveBlockedNumbers(current);
  }

  /// Remove a blocked number
  Future<void> unblockNumber(String number) async {
    final current = await loadBlockedNumbers();

    current.removeWhere((e) => e.number == number);

    await saveBlockedNumbers(current);
  }

  /// Check if a number is blocked
  Future<bool> isBlocked(String number) async {
    final current = await loadBlockedNumbers();
    return current.any((e) => e.number == number);
  }
}
