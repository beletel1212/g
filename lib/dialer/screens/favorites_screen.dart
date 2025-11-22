import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:contacts_service/contacts_service.dart';

import 'package:gofer/dialer/controller/favorites_controller.dart';
import 'package:url_launcher/url_launcher.dart';

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
            final name = c.displayName ?? "Unknown";

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
                    final num = c.phones?.isNotEmpty == true
                        ? c.phones!.first.value
                        : null;

                    if (num != null) {
                      // Standard dialer action
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
                      .removeFavorite(c.identifier!);
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
    // If contact has a photo
    if (c.avatar != null && c.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: MemoryImage(c.avatar!),
      );
    }

    // Otherwise use first letter
    final fallbackLetter =
        (c.displayName?.isNotEmpty ?? false) ? c.displayName![0] : "?";

    return CircleAvatar(
      radius: 24,
      child: Text(fallbackLetter),
    );
  }
}
