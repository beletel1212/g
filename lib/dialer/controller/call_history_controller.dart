import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gofer/dialer/repository/call_history_repository.dart';

/// State for call history
class CallHistoryState {
  final List<CallHistoryEntry> entries;
  final bool isLoading;

  CallHistoryState({required this.entries, this.isLoading = false});

  CallHistoryState copyWith({List<CallHistoryEntry>? entries, bool? isLoading}) {
    return CallHistoryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Controller for call history
class CallHistoryController extends StateNotifier<CallHistoryState> {
  final CallHistoryRepository repository;

  CallHistoryController({required this.repository})
      : super(CallHistoryState(entries: [], isLoading: true)) {
    loadHistory();
  }

  /// Load history from repository
  void loadHistory() {
    final history = repository.getCallHistory();
    state = state.copyWith(entries: history, isLoading: false);
  }

  /// Add new call to history
  Future<void> addCall(CallHistoryEntry entry) async {
    await repository.addCall(entry);
    loadHistory();
  }

  /// Delete a call entry
  Future<void> deleteCall(CallHistoryEntry entry) async {
    await repository.deleteCall(entry);
    loadHistory();
  }

  /// Clear all history
  Future<void> clearHistory() async {
    await repository.clearHistory();
    loadHistory();
  }
}

/// Provider for SharedPreferences (if not already)
final sharedPrefsProvider = FutureProvider((ref) async {
  throw UnimplementedError(); // Use existing sharedPrefsProvider if available
});

/// Provider for CallHistoryController
final callHistoryControllerProvider =
    StateNotifierProvider<CallHistoryController, CallHistoryState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider).value;
  if (prefs != null) {
    final repo = CallHistoryRepository(prefs);
    return CallHistoryController(repository: repo);
  } else {
    throw Exception('SharedPreferences not initialized');
  }
});
