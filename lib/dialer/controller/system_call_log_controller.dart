//import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_log/call_log.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gofer/dialer/repository/call_log_repository.dart';

class SystemCallLogState {
  final List<CallLogEntry> logs;
  final bool isLoading;

  SystemCallLogState({required this.logs, this.isLoading = false});

  SystemCallLogState copyWith({
    List<CallLogEntry>? logs,
    bool? isLoading,
  }) {
    return SystemCallLogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SystemCallLogController extends StateNotifier<SystemCallLogState> {
  final SystemCallLogRepository repository;

  SystemCallLogController({required this.repository})
      : super(SystemCallLogState(logs: [], isLoading: true));

  /// Load call logs from Android system
  Future<void> loadCallLogs() async {
    state = state.copyWith(isLoading: true);
    final logs = await repository.getSystemCallLogs();
    state = state.copyWith(logs: logs, isLoading: false);
  }
}

/// Provider
final systemCallLogProvider =
    StateNotifierProvider<SystemCallLogController, SystemCallLogState>((ref) {
  return SystemCallLogController(repository: SystemCallLogRepository());
});
