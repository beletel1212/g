import 'package:gofer/dialer/screens/dialer_pad_screen.dart';
import 'package:flutter/material.dart';
import 'package:gofer/dialer/services/incoming_call_service.dart';
import 'journal_screen.dart';
import 'contacts_screen.dart';
import 'favorites_screen.dart';

/// Home screen with Material 3 TabBar: Journal, Contacts, Favorites
class DialerHomeScreen extends StatefulWidget {
  const DialerHomeScreen({super.key});

  @override
  State<DialerHomeScreen> createState() => _DialerHomeScreenState();
}

class _DialerHomeScreenState extends State<DialerHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Start listening for incoming calls
    // Ensures IncomingCallService uses a valid BuildContext after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IncomingCallService().initialize(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialer'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Journal'),
            Tab(text: 'Contacts'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          JournalScreen(),
          ContactsScreen(),
          FavoritesScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DialerPadScreen()),
          );
        },
        child: const Icon(Icons.dialpad),
      ),
    );
  }
}
