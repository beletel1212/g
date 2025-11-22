import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofer/dialer/controller/blocked_numbers_controller.dart';   

/// Displays full call history for a single number and offers actions.
class CallDetailsPage extends ConsumerStatefulWidget {
  final String number;
  final String? name;

  const CallDetailsPage({
    super.key,
    required this.number,
    this.name,
  });

  @override
  ConsumerState<CallDetailsPage> createState() => _CallDetailsPageState();
}

class _CallDetailsPageState extends ConsumerState<CallDetailsPage> {
  List<CallLogEntry> _logs = [];
  Contact? _contact;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Loads everything: contact info + call logs
  Future<void> _loadData() async {
    await Permission.contacts.request();
    await Permission.phone.request();

    await _loadContact();
    await _loadCallLogs();
  }

  /// Looks for a contact with this number
  Future<void> _loadContact() async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    String normalized = widget.number.replaceAll(RegExp(r'\D'), "");

    for (var c in contacts) {
      for (var phone in c.phones ?? []) {
        if ((phone.value ?? "").replaceAll(RegExp(r'\D'), "") == normalized) {
          setState(() => _contact = c);
          return;
        }
      }
    }
  }

  /// Loads call logs for this number only
  Future<void> _loadCallLogs() async {
    Iterable<CallLogEntry> logs = await CallLog.query();
    String normalized = widget.number.replaceAll(RegExp(r'\D'), "");

    setState(() {
      _logs = logs
          .where((log) =>
              (log.number ?? "").replaceAll(RegExp(r'\D'), "") == normalized)
          .toList()
        ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
    });
  }

  /// Builds the circular avatar at top
  Widget _buildLargeAvatar() {
    // Contact has a photo
    if (_contact != null &&
        _contact!.avatar != null &&
        _contact!.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: MemoryImage(_contact!.avatar!),
      );
    }

    // Contact exists but no photo
    if (_contact != null) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: Colors.blueGrey.shade300,
        child: Text(
          (_contact!.displayName?.isNotEmpty ?? false)
              ? _contact!.displayName![0].toUpperCase()
              : "?",
          style: const TextStyle(color: Colors.white, fontSize: 32),
        ),
      );
    }

    // No contact
    return const CircleAvatar(
      radius: 48,
      child: Icon(Icons.person, size: 48),
    );
  }

  /// Converts call type to readable string
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

  /// Returns icon based on call type
  IconData _iconForType(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
      case CallType.rejected:
        return Icons.call_end;
      default:
        return Icons.call;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _contact?.displayName ?? widget.name ?? widget.number;

    // Blocking status from our controller
    final isBlocked = ref
        .read(blockedNumbersControllerProvider.notifier)
        .isBlocked(widget.number);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Call Details"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---- AVATAR + NAME ----
          Column(
            children: [
              _buildLargeAvatar(),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_contact == null)
                Text(
                  widget.number,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
            ],
          ),

          const SizedBox(height: 25),

          // ---- ACTION BUTTONS: CALL / SMS / VIDEO ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.phone,
                label: "Call",
                onTap: () {
                  // TODO: Integrate with dialerPadController
                },
              ),
              _ActionButton(
                icon: Icons.message,
                label: "Message",
                onTap: () {
                  // TODO: SMS
                },
              ),
              _ActionButton(
                icon: Icons.videocam,
                label: "Video",
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          // ---- HISTORY TITLE ----
          const Text(
            "Call History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),

          // ---- CALL LOGS LIST ----
          ..._logs.map((log) {
            return ListTile(
              leading: Icon(
                _iconForType(log.callType),
                color: log.callType == CallType.missed ? Colors.red : Colors.green,
              ),
              title: Text(_callTypeName(log.callType)),
              subtitle: Text(
                "${DateTime.fromMillisecondsSinceEpoch(log.timestamp ?? 0)}",
              ),
              trailing: Text("${log.duration ?? 0}s"),
            );
          }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // ---- ADD TO CONTACTS ----
          if (_contact == null)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text("Add to contacts"),
              onTap: () {
                // TODO: Add to contacts
              },
            ),

          // ---- BLOCK / UNBLOCK ----
          ListTile(
            leading: Icon(
              isBlocked ? Icons.block_flipped : Icons.block,
              color: Colors.red,
            ),
            title: Text(isBlocked ? "Unblock number" : "Block number"),
            onTap: () async {
              if (isBlocked) {
                await ref
                    .read(blockedNumbersControllerProvider.notifier)
                    .unblockNumber(widget.number);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Number unblocked")),
                );
              } else {
                await ref
                    .read(blockedNumbersControllerProvider.notifier)
                    .blockNumber(widget.number);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Number blocked")),
                );
              }

              setState(() {});
            },
          ),

          // ---- DELETE CALL HISTORY FOR THIS NUMBER ----
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text("Delete call history for this number"),
            onTap: () {
              // TODO: Delete from call log (Android API)
            },
          ),
        ],
      ),
    );
  }
}

/// Small round button for call/message/video
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          child: IconButton(
            icon: Icon(icon, size: 24),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    );
  }
}
