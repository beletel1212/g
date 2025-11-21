import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Model for a call history entry
class CallHistoryEntry {
  final String number;
  final DateTime timestamp;
  final CallType type;

  CallHistoryEntry({
    required this.number,
    required this.timestamp,
    required this.type,
  });

  /// Convert to Map for storage
  Map<String, dynamic> toMap() => {
        'number': number,
        'timestamp': timestamp.toIso8601String(),
        'type': type.index,
      };

  /// Create from Map
  factory CallHistoryEntry.fromMap(Map<String, dynamic> map) => CallHistoryEntry(
        number: map['number'],
        timestamp: DateTime.parse(map['timestamp']),
        type: CallType.values[map['type']],
      );
}

/// Enum for call type
enum CallType { incoming, outgoing, missed }

/// Repository for storing and retrieving call history
class CallHistoryRepository {
  final SharedPreferences prefs;
  static const String historyKey = 'call_history';

  CallHistoryRepository(this.prefs);

  /// Get all call history entries
  List<CallHistoryEntry> getCallHistory() {
    final rawList = prefs.getStringList(historyKey) ?? [];
    return rawList
        .map((e) => CallHistoryEntry.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // latest first
  }

  /// Add a new call to history
  Future<void> addCall(CallHistoryEntry entry) async {
    final current = prefs.getStringList(historyKey) ?? [];
    current.add(jsonEncode(entry.toMap()));
    await prefs.setStringList(historyKey, current);
  }

  /// Delete a call entry
  Future<void> deleteCall(CallHistoryEntry entry) async {
    final current = prefs.getStringList(historyKey) ?? [];
    current.removeWhere((e) {
      final map = Map<String, dynamic>.from(jsonDecode(e));
      return map['number'] == entry.number &&
          map['timestamp'] == entry.timestamp.toIso8601String();
    });
    await prefs.setStringList(historyKey, current);
  }

  /// Clear all call history
  Future<void> clearHistory() async {
    await prefs.remove(historyKey);
  }
}
