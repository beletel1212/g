import 'package:call_log/call_log.dart';

class SystemCallLogRepository {
  /// Fetch REAL Android system call logs
  Future<List<CallLogEntry>> getSystemCallLogs() async {
    final Iterable<CallLogEntry> entries = await CallLog.query();
    return entries.toList();
  }
}
