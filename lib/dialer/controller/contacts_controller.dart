import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // Changed: use flutter_contacts
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// ---------------------------------------------------------------------------
/// ContactsController
///
/// - Handles WRITE operations involving device contacts
/// - Used by CallDetailsPage ("Add to contacts")
/// - Uses flutter_contacts plugin (updated)
///
/// NOTE: We do not load all contacts here. This controller ONLY performs
/// write / update tasks triggered by UI actions.
/// ---------------------------------------------------------------------------
class ContactsController extends Notifier<void> {
  @override
  void build() {
    // No state needed – this controller only performs actions.
  }

  /// Creates a brand-new contact using the phone number only.
  /// Called when user taps: "Add to contacts" in CallDetailsPage.
  Future<bool> addNewContactFromNumber(String number) async {
    try {
      // Request contact permission (READ + WRITE)
      // flutter_contacts needs this explicit permission
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        debugPrint("Contacts permission denied");
        return false;
      }

      // flutter_contacts requires explicit runtime permission check
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        debugPrint("FlutterContacts permission denied");
        return false;
      }

      // Create new Contact entry
      final newContact = Contact()
        ..name.first = "New Contact" // Default display name
        ..phones = [
          Phone(number, label: PhoneLabel.mobile),
        ];

      /// CHANGED: flutter_contacts uses `insert()` instead of ContactsService.addContact()
      await newContact.insert();

      debugPrint("Contact added: $number");
      return true;
    } catch (e) {
      debugPrint("Error adding contact: $e");
      return false;
    }
  }

  /// Adds the number to an existing contact (placeholder for future update)
  /// We do not use this in the CallDetailsPage yet, but it keeps the design expandable.
  Future<bool> addNumberToExistingContact(Contact contact, String number) async {
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) return false;

      // flutter_contacts explicit permission request
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) return false;

      // Add new number to contact
      contact.phones.add(
        Phone(number, label: PhoneLabel.mobile),
      );

      /// CHANGED: flutter_contacts uses `update()` instead of ContactsService.updateContact()
      await contact.update();
      return true;
    } catch (e) {
      debugPrint("Error updating existing contact: $e");
      return false;
    }
  }
}

/// Riverpod provider for the controller
final contactsControllerProvider =
    NotifierProvider<ContactsController, void>(() {
  return ContactsController();
});
