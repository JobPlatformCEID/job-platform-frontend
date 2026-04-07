import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../user.dart';
import 'waiting_room.dart';

class CallsScreen extends StatefulWidget {
  final Auth auth;
  final Server server;
  final String? searchQuery;

  const CallsScreen({super.key, required this.auth, required this.server, this.searchQuery});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.auth.user!.server.sendGetList(
        '/api/calls/',
        token: widget.auth.user!.token,
      );
      setState(() => _rooms = response);
    } catch (e) {
      setState(() => _error = 'Failed to load rooms: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createRoom() async {
    final controller = TextEditingController();
    final dateController = TextEditingController();
    final descController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Video Call Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                hintText: 'e.g., Interview with John',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., Technical interview for frontend position',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'Meeting Date (optional)',
                hintText: 'YYYY-MM-DD HH:MM',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    controller.dispose();
    dateController.dispose();
    descController.dispose();

    if (result == true && controller.text.isNotEmpty) {
      try {
        final response = await widget.auth.user!.server.sendPost(
          '/api/calls/',
          {
            'room_name': controller.text,
            'description': descController.text,
            if (dateController.text.isNotEmpty) 'meeting_date': dateController.text,
          },
          token: widget.auth.user!.token,
        );
        _fetchRooms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room created successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          debugPrint('Error creating room: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create room: $e'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  void _joinRoom(int roomId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallWaitingRoom(
          auth: widget.auth,
          roomId: roomId.toString(),
        ),
      ),
    ).then((_) => _fetchRooms());
  }

  Future<void> _deleteRoom(int roomId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: const Text('Are you sure you want to delete this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.auth.user!.server.sendDelete(
          '/api/calls/$roomId/',
          token: widget.auth.user!.token,
        );
        _fetchRooms();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete room: $e')),
          );
        }
      }
    }
  }

  bool get isEmployer => widget.auth.user is Employer;

  @override
  Widget build(BuildContext context) {
    final filteredRooms = widget.searchQuery == null || widget.searchQuery!.isEmpty
        ? _rooms
        : _rooms.where((room) =>
            (room['room_name'] as String? ?? '').toLowerCase().contains(widget.searchQuery!.toLowerCase())
        ).toList();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchRooms,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : filteredRooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_call_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            widget.searchQuery != null && widget.searchQuery!.isNotEmpty
                                ? 'No rooms found'
                                : 'No video call rooms yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRooms.length,
                      itemBuilder: (context, index) {
                        final room = filteredRooms[index];
                        final roomId = room['id'] as int;
                        final roomName = room['room_name'] as String? ?? 'Unknown';
                        final host = room['host'] as String? ?? 'Unknown';
                        final isActive = room['is_active'] as bool? ?? false;
                        final meetingDate = room['meeting_date'] as String?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isActive ? Colors.green : Colors.grey,
                              child: Icon(
                                isActive ? Icons.videocam : Icons.videocam_off,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(roomName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Host: $host'),
                                if (meetingDate != null) Text('Meeting: $meetingDate'),
                                Text(isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    )),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.video_call),
                                  onPressed: () => _joinRoom(roomId),
                                  tooltip: 'Join Room',
                                ),
                                if (widget.auth.user!.username == host)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteRoom(roomId),
                                    tooltip: 'Delete Room',
                                    color: Colors.red,
                                  ),
                              ],
                            ),
                            onTap: () => _joinRoom(roomId),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRoom,
        child: const Icon(Icons.add),
        tooltip: 'Create Room',
      ),
    );
  }
}
