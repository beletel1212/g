import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:gofer/dialer/screens/call_details_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';

/// JournalScreen loads all call logs once, supports pagination,
/// and displays contact photos using contacts_service.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final ScrollController _scrollController = ScrollController();

  // Full logs
  List<CallLogEntry> _allLogs = [];

  // Visible logs
  List<CallLogEntry> _visibleLogs = [];

  // All contacts from the phone
  Map<String, Contact> _contactsByNumber = {};

  static const int _pageSize = 30;

  bool _loadingInitial = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  /// Loads permissions, contacts, and call logs
  Future<void> _loadInitialData() async {
    setState(() => _loadingInitial = true);

    // Request phone + contacts permissions
    await Permission.phone.request();
    await Permission.contacts.request();

    // Load contacts
    await _loadContacts();

    // Load logs
    await _loadCallLogs();

    setState(() => _loadingInitial = false);
  }

  /// Loads all contacts and indexes them by phone number for quick lookup.
  Future<void> _loadContacts() async {
    Iterable<Contact> contacts = await ContactsService.getContacts(
      withThumbnails: true,
    );

    // Normalize numbers & store in a map for fast lookup
    for (var c in contacts) {
      for (var phone in c.phones ?? []) {
        final normalized = phone.value?.replaceAll(RegExp(r'\D'), "") ?? "";
        if (normalized.isNotEmpty) {
          _contactsByNumber[normalized] = c;
        }
      }
    }
  }

  /// Loads all call logs then paginates locally.
  Future<void> _loadCallLogs() async {
    Iterable<CallLogEntry> entries = await CallLog.query();

    _allLogs = entries.toList()
      ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

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
  Widget _buildContactAvatar(CallLogEntry log) {
    final number = log.number?.replaceAll(RegExp(r'\D'), "") ?? "";

    final contact = _contactsByNumber[number];

    // If contact exists with a photo
    if (contact != null && contact.avatar != null && contact.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: MemoryImage(contact.avatar!),
      );
    }

    // If contact exists WITHOUT a photo
    if (contact != null) {
      final initial = (contact.displayName?.isNotEmpty ?? false)
          ? contact.displayName![0].toUpperCase()
          : "?";

      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blueGrey.shade300,
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
      );
    }

    // No contact — return generic icon
    return const CircleAvatar(
      radius: 24,
      child: Icon(Icons.person),
    );
  }

  /// Call type text
  String _callTypeName(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return "Incoming";
      case CallType.outgoing:
        return "Outgoing";
      case CallType.missed:
        return "Missed";
      case CallType.rejected:
        return "Rejected";
      default:
        return "Unknown";
    }
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

          return ListTile(
  leading: _buildContactAvatar(log),
  title: Text(log.name ?? log.number ?? "Unknown"),
  subtitle: Text(
    "${_callTypeName(log.callType)} • "
    "${DateTime.fromMillisecondsSinceEpoch(log.timestamp ?? 0)}",
  ),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallDetailsPage(
          number: log.number ?? "",
          name: log.name,
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
