import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/blocked_number.dart';
import '../repository/blocked_numbers_repository.dart';

/// Controller (StateNotifier) that wraps the repository and
/// exposes reactive state to the UI
class BlockedNumbersController
    extends StateNotifier<List<BlockedNumber>> {
      
  final BlockedNumbersRepository repository;

  BlockedNumbersController(this.repository) : super([]) {
    _loadInitial();
  }

  /// Load existing blocked numbers on startup
  Future<void> _loadInitial() async {
    final list = await repository.loadBlockedNumbers();
    state = list;
  }

  /// Block a number
  Future<void> blockNumber(String number) async {
    await repository.blockNumber(number);
    state = [...state, BlockedNumber(number: number, blockedAt: DateTime.now())];
  }

  /// Unblock a number
  Future<void> unblockNumber(String number) async {
    await repository.unblockNumber(number);
    state = state.where((e) => e.number != number).toList();
  }

  /// Check if number is blocked (fast lookup using current state)
  bool isBlocked(String number) {
    return state.any((e) => e.number == number);
  }
}

/// Riverpod provider for the controller
final blockedNumbersRepositoryProvider = Provider((ref) {
  return BlockedNumbersRepository();
});

final blockedNumbersControllerProvider =
    StateNotifierProvider<BlockedNumbersController, List<BlockedNumber>>((ref) {
  final repo = ref.read(blockedNumbersRepositoryProvider);
  return BlockedNumbersController(repo);
});
