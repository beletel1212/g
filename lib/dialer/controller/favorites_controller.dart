import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:contacts_service/contacts_service.dart';   // REMOVED (no longer used)
import 'package:flutter_contacts/flutter_contacts.dart';     // ADDED: flutter_contacts API
//import 'package:flutter_contacts/contact.dart';
import 'package:gofer/dialer/repository/favorites_repository.dart';

/// Provider for repository (shared across app)
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

/// Holds full list of favorite contacts as actual `Contact` objects.
/// Uses AsyncNotifier to auto-load on app start.
class FavoritesController extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() async {
    return await _loadFavorites();
  }

  /// Loads favorite IDs from repository and fetches matching Contacts.
  Future<List<Contact>> _loadFavorites() async {
    final repo = ref.read(favoritesRepositoryProvider);
    final favoriteIds = await repo.getFavoriteContacts();

    if (favoriteIds.isEmpty) return [];

    // -------------------------------------------------------------------------
    // CHANGED:
    // ContactsService.getContacts() → FlutterContacts.getContacts()
    // NOTE: Must enable withProperties:true to load phone numbers & identifiers.
    // -------------------------------------------------------------------------
    final all = await FlutterContacts.getContacts(
      withProperties: true,
    );

    // -------------------------------------------------------------------------
    // CHANGED:
    // Old field: c.identifier
    // New field: c.id (flutter_contacts uses 'id')
    // -------------------------------------------------------------------------
    final filtered = all.where((c) {
      return favoriteIds.contains(c.id);
    }).toList();

    return filtered;
  }

  /// Adds a contact to favorites
  Future<void> addFavorite(String contactId) async {
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.addFavorite(contactId);

    // Refresh state
    state = AsyncData(await _loadFavorites());
  }

  /// Removes a contact from favorites
  Future<void> removeFavorite(String contactId) async {
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.removeFavorite(contactId);

    // Refresh state
    state = AsyncData(await _loadFavorites());
  }

  /// Toggles favorite on/off
  Future<void> toggleFavorite(String contactId) async {
    final repo = ref.read(favoritesRepositoryProvider);

    final isFav = await repo.isFavorite(contactId);

    if (isFav) {
      await repo.removeFavorite(contactId);
    } else {
      await repo.addFavorite(contactId);
    }

    // Refresh UI
    state = AsyncData(await _loadFavorites());
  }

  /// Public getter: checks if contact is favorite without rebuilding controller.
  Future<bool> isFavorite(String contactId) async {
    final repo = ref.read(favoritesRepositoryProvider);
    return repo.isFavorite(contactId);
  }
}

/// Provider for FavoritesController
final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<Contact>>(
        FavoritesController.new);
