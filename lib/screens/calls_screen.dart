// Screen for browsing and joining video call rooms
import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../user.dart';
import 'video_call_screen.dart';

class Room {
  final int id;
  final String roomName;
  final String host;
  final String meetingDate;
  final String description;
  final String createdAt;

  const Room({
    required this.id,
    required this.roomName,
    required this.host,
    required this.meetingDate,
    required this.description,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id:          json['id']           as int,
        roomName:    json['room_name']    as String,
        host:        json['host']         as String,
        meetingDate: json['meeting_date'] as String? ?? '',
        description: json['description']  as String? ?? '',
        createdAt:   json['created_at']   as String? ?? '',
      );

  static Future<List<Room>> fetchAll(Server server, String token) async {
    final list = await server.sendGetList('/api/calls/', token: token);
    return list.map((r) => Room.fromJson(r)).toList();
  }

  static Future<Room> create(Server server, String token,
      {required String roomName,
      required String meetingDate,
      required String description}) async {
    final data = await server.sendPost('/api/calls/', {
      'room_name':    roomName,
      'meeting_date': meetingDate,
      'description':  description,
    }, token: token);
    return Room.fromJson(data);
  }

  Future<void> delete(Server server, String token) =>
      server.sendDelete('/api/calls/$id/', token: token);
}

class CallsScreen extends StatefulWidget {
  final Auth auth;
  final Server server;
  final String searchQuery;

  const CallsScreen({
    super.key,
    required this.auth,
    required this.server,
    required this.searchQuery,
  });

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<Room> _rooms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CallsScreen old) {
    super.didUpdateWidget(old);
    if (old.searchQuery != widget.searchQuery) setState(() {});
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final rooms = await Room.fetchAll(widget.server, widget.auth.user!.token);
      if (mounted) setState(() { _rooms = rooms; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  // Get token and enter the call
  Future<void> _join(Room room) async {
    // Show a loading indicator while fetching the token
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resp = await widget.server.sendGet(
        '/api/calls/${room.id}/join/',
        token: widget.auth.user!.token,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader

      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          livekitUrl:   resp['livekit_url']   as String,
          livekitToken: resp['livekit_token'] as String,
          roomName:     resp['room_name']     as String,
          isHost:       resp['is_host']       as bool? ?? false,
        ),
      ));
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    }
  }

  Future<void> _delete(Room room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Delete "${room.roomName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await room.delete(widget.server, widget.auth.user!.token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Room deleted')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreate() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? date;
    TimeOfDay? time;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Create Room'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Room Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(date == null
                    ? 'Select Date'
                    : date!.toLocal().toString().split(' ')[0]),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setD(() => date = d);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(time == null ? 'Select Time' : time!.format(ctx)),
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: TimeOfDay.now());
                  if (t != null) setD(() => time = t);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || date == null || time == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Fill all fields')));
                  return;
                }
                final dt = DateTime(date!.year, date!.month, date!.day,
                    time!.hour, time!.minute);
                try {
                  await Room.create(widget.server, widget.auth.user!.token,
                      roomName:    nameCtrl.text,
                      meetingDate: dt.toUtc().toIso8601String(),
                      description: descCtrl.text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _load();
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  List<Room> get _filtered {
    if (widget.searchQuery.isEmpty) return _rooms;
    final q = widget.searchQuery.toLowerCase();
    return _rooms
        .where((r) =>
            r.roomName.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q) ||
            r.host.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEmployer = widget.auth.user is Employer;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final rooms = _filtered;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: rooms.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.videocam_off_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    widget.searchQuery.isEmpty
                        ? 'No rooms available'
                        : 'No rooms match your search',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: rooms.length,
                itemBuilder: (_, i) {
                  final room = rooms[i];
                  final isHost = room.host == widget.auth.user?.username;
                  return Card(
                    child: ListTile(
                      title: Text(room.roomName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Host: ${room.host}'),
                          if (room.meetingDate.isNotEmpty)
                            Text(_fmt(room.meetingDate)),
                          if (room.description.isNotEmpty)
                            Text(room.description,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      isThreeLine: room.description.isNotEmpty,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isHost)
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error),
                            onPressed: () => _delete(room),
                          ),
                        FilledButton(
                          onPressed: () => _join(room),
                          child: const Text('Join'),
                        ),
                      ]),
                      onTap: () => _join(room),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: isEmployer
          ? FloatingActionButton(
              onPressed: _showCreate, child: const Icon(Icons.add))
          : null,
    );
  }

  String _fmt(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}