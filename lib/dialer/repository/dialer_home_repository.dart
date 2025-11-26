//import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // CHANGED: Replace ContactsService with flutter_contacts API
//import 'package:flutter_contacts/contact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// Repository for managing contacts and favorites
class DialerHomeRepository {
  final SharedPreferences prefs;

  DialerHomeRepository(this.prefs);

  /// Fetch all device contacts (with permission check)
  Future<List<Contact>> fetchContacts() async {
    // CHANGED: flutter_contacts requires explicit permission check first
    if (await Permission.contacts.request().isGranted) {
      // CHANGED: Replace ContactsService.getContacts() with FlutterContacts.getContacts()
      // NOTE: withProperties=true loads phone numbers, emails, etc.
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,      // CHANGED: must be true to access phone numbers
        withThumbnail: false,       // CHANGED: equivalent to old "withThumbnails: false"
      );

      return contacts;
    } else {
      return [];
    }
  }

  /// Load favorite contacts by IDs
  List<Contact> loadFavorites(List<Contact> contacts) {
    final favoriteIds = prefs.getStringList('favorites') ?? [];

    // CHANGED: flutter_contacts uses "id" instead of "identifier"
    return contacts.where((c) => favoriteIds.contains(c.id)).toList();
  }

  /// Save favorite contact IDs to SharedPreferences
  Future<void> saveFavorites(List<Contact> favorites) async {
    // CHANGED: flutter_contacts uses "id" instead of "identifier"
    final favoriteIds = favorites
        // ignore: unnecessary_null_comparison
        .where((c) => c.id != null)
        .map((c) => c.id)
        .toList();

    await prefs.setStringList('favorites', favoriteIds);
  }
}
