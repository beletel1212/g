import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ❌ REMOVE contacts_service
// import 'package:contacts_service/contacts_service.dart';

// ✅ ADD flutter_contacts
import 'package:flutter_contacts/flutter_contacts.dart';   // <-- NEW/CHANGED (flutter_contacts)

import 'package:gofer/dialer/controller/favorites_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart'; // import global contactsCache

/// Favorites tab powered by real FavoritesController.
/// Uses the same UI layout you already had.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesControllerProvider);

    return favoritesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
      data: (favoriteContacts) {
        if (favoriteContacts.isEmpty) {
          return const Center(
            child: Text(
              "No favorites yet",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: favoriteContacts.length,
          itemBuilder: (context, index) {
            final Contact c = favoriteContacts[index];

            // Use global contactsCache if available for displayName
            String name = "Unknown";
            if (c.phones.isNotEmpty) {
              final normalized = c.phones.first.number.replaceAll(RegExp(r'\D'), "");
              if (contactsCache.containsKey(normalized)) {
                name = contactsCache[normalized]?.displayName ?? "Unknown";
              } else {
                name = c.displayName.isNotEmpty ? c.displayName : "Unknown";
              }
            } else {
              name = c.displayName.isNotEmpty ? c.displayName : "Unknown";
            }

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: _buildAvatar(c),
                title: Text(name),

                // Call button
                trailing: IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () {
                    // Use first phone number
                    final num = c.phones.isNotEmpty ? c.phones.first.number : null;

                    if (num != null) {
                      launchUrl(Uri(scheme: 'tel', path: num));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No phone number')),
                      );
                    }
                  },
                ),

                // Tap = open contact detail (optional)
                onTap: () {
                  // TODO: navigate to contact detail or call details screen
                },

                // Long press = remove favorite
                onLongPress: () async {
                  ref
                      .read(favoritesControllerProvider.notifier)
                      .removeFavorite(c.id); // flutter_contacts uses c.id
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Builds avatar for each favorite contact
  Widget _buildAvatar(Contact c) {
    // flutter_contacts: photo field instead of avatar
    if (c.photo != null && c.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: MemoryImage(c.photo!),
      );
    }

    // Otherwise use first letter
    final fallbackLetter = c.displayName.isNotEmpty ? c.displayName[0] : "?";

    return CircleAvatar(
      radius: 24,
      child: Text(fallbackLetter),
    );
  }
}
