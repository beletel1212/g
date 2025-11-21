import 'package:flutter/material.dart';

/// Contacts tab placeholder with Material 3 ListTiles
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Example contacts list
    final contacts = List.generate(20, (index) => "Contact ${index + 1}");

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final name = contacts[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 24,
              child: Text(name[0]),
            ),
            title: Text(name),
            subtitle: const Text("Phone number here"),
            trailing: const Icon(Icons.call),
          ),
        );
      },
    );
  }
}
