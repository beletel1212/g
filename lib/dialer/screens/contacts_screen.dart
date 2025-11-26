import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gofer/dialer/controller/favorites_controller.dart';
import 'package:gofer/dialer/screens/call_details_page.dart';

import '../../main.dart'; // <-- uses global contactsCache (Map<String, Contact>)

/// Standard Contacts screen for a default dialer app.
/// - Loads contacts (with phone numbers & photos)
/// - Caches normalized numbers into global `contactsCache` for fast lookup
/// - Search/filter by name or number
/// - Tap → CallDetailsPage, Call button → native dialer
/// - Long-press → toggle favorite (via favoritesController)
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Contact> _allContacts = [];
  List<Contact> _visibleContacts = [];

  static const int _pageSize = 50; // incremental load page size

  bool _loading = true;
  bool _loadingMore = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Loads contacts from device (with properties & photo).
  /// - Requests permission if needed.
  /// - Populates global `contactsCache` keyed by normalized phone number.
  /// - Keeps a local sorted list and shows the first page.
  Future<void> _loadContacts() async {
    setState(() => _loading = true);

    // Request runtime permission (also handled by flutter_contacts)
    await Permission.contacts.request();

    if (!await FlutterContacts.requestPermission()) {
      // Permission denied → show empty state
      setState(() {
        _allContacts = [];
        _visibleContacts = [];
        _loading = false;
      });
      return;
    }

    // Fetch contacts with properties & photo (required for number & avatar)
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );

    // Sort alphabetically by displayName
    contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    // Update global cache for fast lookup by other screens
    for (var c in contacts) {
      for (var phone in c.phones) {
        final normalized = phone.number.replaceAll(RegExp(r'\D'), '');
        if (normalized.isNotEmpty && !contactsCache.containsKey(normalized)) {
          contactsCache[normalized] = c;
        }
      }
    }

    setState(() {
      _allContacts = contacts;
      _visibleContacts = _allContacts.take(_pageSize).toList();
      _loading = false;
    });
  }

  /// Search text changed — apply filter locally and reset visible list
  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q == _query) return;
    _query = q;
    _applyFilter();
  }

  /// Applies current search query to _allContacts and resets pagination
  void _applyFilter() {
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? _allContacts
        : _allContacts.where((c) {
            final name = c.displayName.toLowerCase();
            final phones = c.phones.map((p) => p.number).join(' ').toLowerCase();
            return name.contains(q) || phones.contains(q);
          }).toList();

    setState(() {
      _visibleContacts = filtered.take(_pageSize).toList();
    });
  }

  /// Scroll listener to load more contacts when near bottom
  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.85) {
      _loadMore();
    }
  }

  /// Loads next page of contacts from either filtered or all list
  void _loadMore() {
    final q = _query.toLowerCase();
    final source = q.isEmpty ? _allContacts : _allContacts.where((c) {
      final name = c.displayName.toLowerCase();
      final phones = c.phones.map((p) => p.number).join(' ').toLowerCase();
      return name.contains(q) || phones.contains(q);
    }).toList();

    if (_visibleContacts.length >= source.length) return;

    setState(() => _loadingMore = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      final additional = source.skip(_visibleContacts.length).take(_pageSize).toList();
      setState(() {
        _visibleContacts.addAll(additional);
        _loadingMore = false;
      });
    });
  }

  /// Toggle favorite state for contact by id using favoritesController
  Future<void> _toggleFavorite(Contact contact) async {
    final id = contact.id;
    final favNotifier = ref.read(favoritesControllerProvider.notifier);

    final isFav = await favNotifier.isFavorite(id);

    if (isFav) {
      await favNotifier.removeFavorite(id);
      if (mounted) {
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
        
      }
    } else {
      await favNotifier.addFavorite(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to favorites')));
      }
    }
  }

  /// Launch native dialer with given number
  Future<void> _placeCall(String number) async {
    final tel = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(tel)) {
      await launchUrl(tel);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot place call')));
      }
    }
  }

  Widget _buildAvatar(Contact c) {
    if (c.photo != null && c.photo!.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundImage: MemoryImage(c.photo!));
    }
    final fallback = c.displayName.isNotEmpty ? c.displayName[0] : '?';
    return CircleAvatar(radius: 24, child: Text(fallback));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search contacts or numbers',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),

        Expanded(
          child: _visibleContacts.isEmpty
              ? const Center(child: Text('No contacts found'))
              : ListView.separated(
                  controller: _scrollController,
                  itemCount: _visibleContacts.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _visibleContacts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final c = _visibleContacts[index];

                    // pick the primary phone if available
                    final primaryPhone = c.phones.isNotEmpty ? c.phones.first.number : null;

                    return ListTile(
                      leading: _buildAvatar(c),
                      title: Text(c.displayName.isNotEmpty ? c.displayName : 'Unknown'),
                      subtitle: Text(primaryPhone ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Call',
                            icon: const Icon(Icons.call),
                            onPressed: primaryPhone != null ? () => _placeCall(primaryPhone) : null,
                          ),
                          // Favorite icon (reads state lazily)
                          Consumer(builder: (ctx, ref2, _) {
                            // Async call to isFavorite — keep UI responsive by using FutureBuilder
                            return FutureBuilder<bool>(
                              future: ref2.read(favoritesControllerProvider.notifier).isFavorite(c.id),
                              builder: (ctx2, snap) {
                                final isFav = snap.data ?? false;
                                return IconButton(
                                  tooltip: isFav ? 'Remove favorite' : 'Add favorite',
                                  icon: Icon(isFav ? Icons.star : Icons.star_border),
                                  onPressed: () => _toggleFavorite(c),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                      onTap: () {
                        // Open CallDetailsPage with primary number (if any)
                        final num = primaryPhone ?? '';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallDetailsPage(number: num, name: c.displayName),
                          ),
                        );
                      },
                      onLongPress: () => _toggleFavorite(c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
