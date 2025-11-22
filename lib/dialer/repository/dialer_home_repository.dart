import 'package:contacts_service/contacts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// Repository for managing contacts and favorites
class DialerHomeRepository {
  final SharedPreferences prefs;

  DialerHomeRepository(this.prefs);

  /// Fetch all device contacts (with permission check)
  Future<List<Contact>> fetchContacts() async {
    if (await Permission.contacts.request().isGranted) {
      final Iterable<Contact> contacts =
          await ContactsService.getContacts(withThumbnails: false);
      return contacts.toList();
    } else {
      return [];
    }
  }

  /// Load favorite contacts by IDs
  List<Contact> loadFavorites(List<Contact> contacts) {
    final favoriteIds = prefs.getStringList('favorites') ?? [];
    return contacts
        .where((c) => c.identifier != null && favoriteIds.contains(c.identifier))
        .toList();
  }

  /// Save favorite contact IDs to SharedPreferences
  Future<void> saveFavorites(List<Contact> favorites) async {
    final favoriteIds =
        favorites.where((c) => c.identifier != null).map((c) => c.identifier!).toList();
    await prefs.setStringList('favorites', favoriteIds);
  }
}
