import 'package:flutter/material.dart';
import 'package:gofer/dialer/screens/call_details_page.dart';

// ❌ REMOVE contacts_service
// import 'package:contacts_service/contacts_service.dart';

// ✅ ADD flutter_contacts
import 'package:flutter_contacts/flutter_contacts.dart';  // <-- NEW/CHANGED (flutter_contacts)

import 'package:gofer/dialer/services/incoming_call_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart'; // <-- NEW: for formatting timestamps

import '../../main.dart'; // <-- import global contactsCache

/// JournalScreen loads all call logs once, supports pagination,
/// and displays contact photos using flutter_contacts.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final ScrollController _scrollController = ScrollController();

  // Full logs
  List<Map<String, dynamic>> _allLogs = []; // <-- CHANGED: use Map from service

  // Visible logs
  List<Map<String, dynamic>> _visibleLogs = []; // <-- CHANGED: use Map from service

  static const int _pageSize = 30;

  bool _loadingInitial = true;
  bool _loadingMore = false;

  // Date formatter for readable timestamps
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  /// Loads permissions, contacts, and call logs
  Future<void> _loadInitialData() async {
    setState(() => _loadingInitial = true);

    // Request only contacts permission
    await Permission.contacts.request();

    // Load contacts
    await _loadContacts();

    // Load logs
    await _loadCallLogs();

    setState(() => _loadingInitial = false);
  }

  /// Loads all contacts into the global cache for instant lookup
  Future<void> _loadContacts() async {
    if (!await FlutterContacts.requestPermission()) return;

    final contacts = await FlutterContacts.getContacts(
      withProperties: true, // required for phone numbers
      withPhoto: true,      // fetch avatar
    );

    for (var c in contacts) {
      for (var phone in c.phones) {
        final normalized = phone.number.replaceAll(RegExp(r'\D'), "");
        if (normalized.isNotEmpty && !contactsCache.containsKey(normalized)) {
          contactsCache[normalized] = c; // store in global cache
        }
      }
    }
  }

  /// Loads all call logs from IncomingCallService and paginates locally.
  Future<void> _loadCallLogs() async {
    final logs = await IncomingCallService().getCallLogs(limit: 1000);
    logs.sort((a, b) => (b['date'] ?? 0).compareTo(a['date'] ?? 0));

    _allLogs = logs;
    _visibleLogs = _allLogs.take(_pageSize).toList();
  }

  /// Infinite scroll listener
  void _onScroll() {
    if (_loadingMore || _loadingInitial) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  /// Loads next page of logs
  void _loadMore() {
    if (_visibleLogs.length >= _allLogs.length) return;

    setState(() => _loadingMore = true);

    Future.delayed(const Duration(milliseconds: 250), () {
      final additional = _allLogs
          .skip(_visibleLogs.length)
          .take(_pageSize)
          .toList();

      setState(() {
        _visibleLogs.addAll(additional);
        _loadingMore = false;
      });
    });
  }

  /// Returns contact photo widget OR fallback circle avatar
  /// Adds red border for missed calls
  Widget _buildContactAvatar(Map<String, dynamic> log) {
    final number = (log['number'] as String?)?.replaceAll(RegExp(r'\D'), "") ?? "";
    final contact = contactsCache[number]; // <-- use global cache
    final isMissed = (log['type'] as int? ?? 0) == 3; // <-- missed call check

    Widget avatar;

    if (contact != null) {
      // Contact has a photo
      if (contact.photo != null && contact.photo!.isNotEmpty) {
        avatar = CircleAvatar(
          radius: 24,
          backgroundImage: MemoryImage(contact.photo!),
        );
      } else {
        // Contact exists, no photo
        final initial = contact.displayName.isNotEmpty
            ? contact.displayName[0].toUpperCase()
            : "?";
        avatar = CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blueGrey.shade300,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        );
      }
    } else {
      // Unknown caller
      avatar = const CircleAvatar(
        radius: 24,
        child: Icon(Icons.person),
      );
    }

    // Wrap avatar with red border if missed call
    if (isMissed) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: avatar,
      );
    }

    return avatar;
  }

  /// Maps Android call log types to human-readable names
  String _callTypeName(int? type) {
    switch (type) {
      case 1:
        return "Incoming";
      case 2:
        return "Outgoing";
      case 3:
        return "Missed";
      case 4:
        return "Voicemail";
      case 5:
        return "Rejected";
      default:
        return "Unknown";
    }
  }

  /// Returns icon for call type, with color for missed/incoming/outgoing
  Icon _iconForCallType(int? type) {
    switch (type) {
      case 1:
        return const Icon(Icons.call_received, color: Colors.green);
      case 2:
        return const Icon(Icons.call_made, color: Colors.green);
      case 3:
        return const Icon(Icons.call_missed, color: Colors.red);
      case 4:
        return const Icon(Icons.voicemail, color: Colors.grey);
      case 5:
        return const Icon(Icons.call_missed_outlined, color: Colors.red);
      default:
        return const Icon(Icons.call, color: Colors.grey);
    }
  }

  /// Formats timestamp to human-readable string
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return _dateFormatter.format(date);
  }

  /// Pull-to-refresh
  Future<void> _refresh() async {
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show placeholder if no call history
    if (_visibleLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "No call history available",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _visibleLogs.length + 1,
        itemBuilder: (context, index) {
          if (index == _visibleLogs.length) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final log = _visibleLogs[index];

          // Use cached contact name if available
          final number = (log['number'] as String?) ?? "";
          final contact = contactsCache[number.replaceAll(RegExp(r'\D'), "")];
          final displayName = contact?.displayName ?? log['name'] ?? number;

          // Highlight missed calls in red
          final isMissed = (log['type'] as int? ?? 0) == 3;

          return ListTile(
            leading: _buildContactAvatar(log),
            title: Text(
              displayName,
              style: TextStyle(
                color: isMissed ? Colors.red : null,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              "${_callTypeName(log['type'] as int?)} • "
              "${_formatTimestamp(log['date'] ?? 0)}",
            ),
            trailing: _iconForCallType(log['type'] as int?), // <-- call type icon added
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallDetailsPage(
                    number: log['number'] ?? "",
                    name: displayName,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
