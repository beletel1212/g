import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gofer/dialer/repository/dialer_home_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State for the Dialer Home
class DialerHomeState {
  final List<Contact> contacts;
  final List<Contact> favorites;
  final bool isLoading;

  DialerHomeState({
    required this.contacts,
    required this.favorites,
    this.isLoading = false,
  });

  DialerHomeState copyWith({
    List<Contact>? contacts,
    List<Contact>? favorites,
    bool? isLoading,
  }) {
    return DialerHomeState(
      contacts: contacts ?? this.contacts,
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Controller for Dialer Home
class DialerHomeController extends StateNotifier<DialerHomeState> {
  final DialerHomeRepository repository;

  DialerHomeController({required this.repository})
      : super(DialerHomeState(contacts: [], favorites: [], isLoading: true));

  /// Load contacts and favorites from repository
  Future<void> loadContactsAndFavorites() async {
    state = state.copyWith(isLoading: true);
    final contacts = await repository.fetchContacts();
    final favorites = repository.loadFavorites(contacts);
    state = state.copyWith(contacts: contacts, favorites: favorites, isLoading: false);
  }

  /// Add a contact to favorites
  Future<void> addToFavorites(Contact contact) async {
    if (!state.favorites.contains(contact)) {
      final updatedFavorites = [...state.favorites, contact];
      await repository.saveFavorites(updatedFavorites);
      state = state.copyWith(favorites: updatedFavorites);
    }
  }

  /// Remove a contact from favorites
  Future<void> removeFromFavorites(Contact contact) async {
    final updatedFavorites = state.favorites.where((c) => c != contact).toList();
    await repository.saveFavorites(updatedFavorites);
    state = state.copyWith(favorites: updatedFavorites);
  }
}

/// Provider for SharedPreferences
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Provider for DialerHomeController
final dialerHomeControllerProvider =
    StateNotifierProvider<DialerHomeController, DialerHomeState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider).value;
  if (prefs != null) {
    final repo = DialerHomeRepository(prefs);
    return DialerHomeController(repository: repo);
  } else {
    throw Exception('SharedPreferences not initialized');
  }
});
