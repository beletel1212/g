import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // flutter_contacts import
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // <-- for formatting timestamps

import 'package:gofer/dialer/controller/blocked_numbers_controller.dart';
import 'package:gofer/dialer/controller/dialer_pad_controller.dart';
import 'package:gofer/dialer/controller/contacts_controller.dart';
import 'package:gofer/dialer/services/incoming_call_service.dart'; // unified call logs

import '../../main.dart'; // import global contactsCache

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
  // Use Map<String, dynamic> instead of IncomingCallLog
  List<Map<String, dynamic>> _logs = [];

  // flutter_contacts Contact model
  Contact? _contact;

  // DateFormat instance for human-readable timestamp
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Loads contact info + call logs
  Future<void> _loadData() async {
    await Permission.contacts.request();
    await Permission.phone.request();

    await _loadContact();
    await _loadCallLogs();
  }

  /// Optimized: lookup contact using global contactsCache
  Future<void> _loadContact() async {
    final normalizedNumber = widget.number.replaceAll(RegExp(r'\D'), "");

    if (contactsCache.containsKey(normalizedNumber)) {
      setState(() {
        _contact = contactsCache[normalizedNumber];
      });
    } else {
      // fallback: in case number is not in cache
      if (!await FlutterContacts.requestPermission()) return;

      final contacts = await FlutterContacts.getContacts(withProperties: true);

      for (var c in contacts) {
        for (var phone in c.phones) {
          final normalized = phone.number.replaceAll(RegExp(r'\D'), "");
          if (normalized == normalizedNumber) {
            setState(() {
              _contact = c;
              contactsCache[normalized] = c; // update cache
            });
            return;
          }
        }
      }
    }
  }

  /// Loads call logs for this number using unified service
  Future<void> _loadCallLogs() async {
    final allLogs = await IncomingCallService().getCallLogs();
    final normalizedNumber = widget.number.replaceAll(RegExp(r'\D'), "");

    setState(() {
      _logs = allLogs
          .where((log) =>
              ((log['number'] as String?)?.replaceAll(RegExp(r'\D'), "") ?? "") ==
              normalizedNumber)
          .toList()
        ..sort((a, b) =>
            (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
    });
  }

  /// Builds the circular avatar
  Widget _buildLargeAvatar() {
    if (_contact != null &&
        _contact!.photo != null &&
        _contact!.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: MemoryImage(_contact!.photo!),
      );
    }

    if (_contact != null) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: Colors.blueGrey.shade300,
        child: Text(
          (_contact!.displayName.isNotEmpty)
              ? _contact!.displayName[0].toUpperCase()
              : "?",
          style: const TextStyle(color: Colors.white, fontSize: 32),
        ),
      );
    }

    return const CircleAvatar(
      radius: 48,
      child: Icon(Icons.person, size: 48),
    );
  }

  /// Converts integer call type to readable string
  String _callTypeName(int? type) {
    switch (type) {
      case 1:
        return "Incoming";
      case 2:
        return "Outgoing";
      case 3:
        return "Missed";
      default:
        return "Unknown";
    }
  }

  /// Returns icon based on integer call type
  IconData _iconForType(int? type) {
    switch (type) {
      case 1:
        return Icons.call_received;
      case 2:
        return Icons.call_made;
      case 3:
        return Icons.call_missed;
      default:
        return Icons.call;
    }
  }

  /// Formats timestamp to human-readable string
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return _dateFormatter.format(date);
  }

  /// Formats duration in seconds to mm:ss
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _contact?.displayName ?? widget.name ?? widget.number;

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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.phone,
                label: "Call",
                onTap: () {
                  ref
                      .read(dialerPadControllerProvider.notifier)
                      .placeCall(context, number: widget.number);
                },
              ),
              _ActionButton(
                icon: Icons.message,
                label: "Message",
                onTap: () async {
                  final smsUri = Uri(scheme: 'sms', path: widget.number);
                  if (await canLaunchUrl(smsUri)) {
                    launchUrl(smsUri);
                  }
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

          const Text(
            "Call History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),

          // Map-based logs with formatted timestamp & duration, missed calls in red
          ..._logs.map((log) {
            final type = log['type'] as int?;
            final duration = log['duration'] as int? ?? 0;
            final timestamp = log['timestamp'] as int? ?? 0;

            return ListTile(
              leading: Icon(
                _iconForType(type),
                color: type == 3 ? Colors.red : Colors.green, // Missed calls red
              ),
              title: Text(
                _callTypeName(type),
                style: TextStyle(
                  color: type == 3 ? Colors.red : Colors.black, // Missed calls text red
                ),
              ),
              subtitle: Text(_formatTimestamp(timestamp)),
              trailing: Text(_formatDuration(duration)), // mm:ss format
            );
          }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          if (_contact == null)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text("Add to contacts"),
              onTap: () async {
                final result = await ref
                    .read(contactsControllerProvider.notifier)
                    .addNewContactFromNumber(widget.number);

                if (!mounted) return;

                if (result) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Contact created")),
                    );
                  }
                  _loadContact();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to add contact")),
                    );
                  }
                }
              },
            ),

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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Number unblocked")),
                  );
                }
              } else {
                await ref
                    .read(blockedNumbersControllerProvider.notifier)
                    .blockNumber(widget.number);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Number blocked")),
                  );
                }
              }
              setState(() {});
            },
          ),

          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text("Delete call history for this number"),
            onTap: () async {
              const channel = MethodChannel("gofer/dialer");
              try {
                await channel.invokeMethod(
                  "deleteCallHistoryForNumber",
                  {"number": widget.number},
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Call history deleted")),
                  );
                }
                _loadCallLogs();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed: $e")),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

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
