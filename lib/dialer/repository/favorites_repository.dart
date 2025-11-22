import 'package:shared_preferences/shared_preferences.dart';

/// Repository responsible for storing and retrieving
/// the list of favorite contacts locally.
///
/// Favorites are stored as a list of contact IDs.
class FavoritesRepository {
  static const String _favoritesKey = 'favorite_contacts';

  /// Returns the list of favorite contact IDs.
  Future<List<String>> getFavoriteContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  /// Adds a contact ID to the favorites list.
  Future<void> addFavorite(String contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_favoritesKey) ?? [];

    if (!current.contains(contactId)) {
      current.add(contactId);
      await prefs.setStringList(_favoritesKey, current);
    }
  }

  /// Removes a contact ID from favorites.
  Future<void> removeFavorite(String contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_favoritesKey) ?? [];

    current.remove(contactId);
    await prefs.setStringList(_favoritesKey, current);
  }

  /// Checks if a contact ID is marked as favorite.
  Future<bool> isFavorite(String contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_favoritesKey) ?? [];
    return current.contains(contactId);
  }

  /// Clears all favorites. (Not used in UI but useful for testing)
  Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }
}
