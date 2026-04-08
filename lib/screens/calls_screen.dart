import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../user.dart';
import 'waiting_room.dart';

class Room {
  final int id;
  final String roomName;
  final String host;
  final String meetingDate;
  final String description;
  final bool isActive;
  final String createdAt;

  const Room({
    required this.id,
    required this.roomName,
    required this.host,
    required this.meetingDate,
    required this.description,
    required this.isActive,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      roomName: json['room_name'] as String,
      host: json['host'] as String,
      meetingDate: json['meeting_date'] as String,
      description: json['description'] as String,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] as String,
    );
  }

  static Future<List<Room>> fetchAll(Server server, String token) async {
    final list = await server.sendGetList('/api/calls/', token: token);
    return list.map((r) => Room.fromJson(r)).toList();
  }

  static Future<Room> create(
    Server server,
    String token, {
    required String roomName,
    required String meetingDate,
    required String description,
  }) async {
    final data = await server.sendPost('/api/calls/', {
      'room_name': roomName,
      'meeting_date': meetingDate,
      'description': description,
    }, token: token);
    return Room.fromJson(data);
  }

  Future<void> delete(Server server, String token) async {
    await server.sendDelete('/api/calls/$id/', token: token);
  }
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
    _loadRooms();
  }

  @override
  void didUpdateWidget(covariant CallsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      setState(() {});
    }
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rooms = await Room.fetchAll(widget.server, widget.auth.user!.token);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load rooms: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _joinRoom(Room room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WaitingRoom(
          auth: widget.auth,
          roomId: room.id.toString(),
        ),
      ),
    );
  }

  Future<void> _deleteRoom(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "${room.roomName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await room.delete(widget.server, widget.auth.user!.token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room deleted')),
        );
        _loadRooms();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete room: $e')),
        );
      }
    }
  }

  void _showCreateRoomDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    hintText: 'Enter room name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter description',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    selectedDate == null
                        ? 'Select Date'
                        : 'Date: ${selectedDate!.toLocal().toString().split(' ')[0]}',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    selectedTime == null
                        ? 'Select Time'
                        : 'Time: ${selectedTime!.format(context)}',
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    selectedDate == null ||
                    selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final dateTime = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );

                final formattedDate = dateTime.toUtc().toIso8601String();

                try {
                  await Room.create(
                    widget.server,
                    widget.auth.user!.token,
                    roomName: nameController.text,
                    meetingDate: formattedDate,
                    description: descController.text,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _loadRooms();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Room created successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create room: $e')),
                    );
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

  List<Room> get _filteredRooms {
    if (widget.searchQuery.isEmpty) return _rooms;
    return _rooms.where((room) {
      return room.roomName.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
          room.description.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
          room.host.toLowerCase().contains(widget.searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    final isEmployer = user is Employer;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadRooms, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filteredRooms = _filteredRooms;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadRooms,
        child: filteredRooms.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.searchQuery.isEmpty
                          ? 'No rooms available'
                          : 'No rooms match your search',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredRooms.length,
                itemBuilder: (context, index) {
                  final room = filteredRooms[index];
                  final isHost = room.host == user?.username;

                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: room.isActive
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      title: Text(room.roomName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Host: ${room.host}'),
                          Text(
                            'Meeting: ${_formatDateTime(room.meetingDate)}',
                            style: TextStyle(
                              color: room.isActive
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (room.description.isNotEmpty)
                            Text(
                              room.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isHost)
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _deleteRoom(room),
                            ),
                          FilledButton(
                            onPressed: () => _joinRoom(room),
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                      onTap: () => _joinRoom(room),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: isEmployer
          ? FloatingActionButton(
              onPressed: _showCreateRoomDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _formatDateTime(String isoDate) {
    final date = DateTime.parse(isoDate);
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
