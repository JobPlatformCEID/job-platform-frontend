import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../user.dart';
import '../calls.dart';
import 'call_room_screen.dart';

class CallsScreen extends StatefulWidget {
  final Auth auth;
  final Server server;

  const CallsScreen({super.key, required this.auth, required this.server});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<CallRoom> _rooms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await CallRoom.fetchAll(widget.server, widget.auth.user!.token);
      if (mounted) setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load rooms.';
      });
    }
  }

  Future<void> _joinRoom(CallRoom room) async {
    try {
      final callToken = await room.getToken(widget.server, widget.auth.user!.token);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CallRoomScreen(
            token: callToken.token,
            url: callToken.url,
            roomName: callToken.roomName,
            isHost: callToken.isHost,
            displayName: room.roomName,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not join room.')),
        );
      }
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoomFormSheet(
        server: widget.server,
        token: widget.auth.user!.token,
        onSaved: (room) => setState(() => _rooms.insert(0, room)),
      ),
    );
  }

  void _showEditSheet(CallRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoomFormSheet(
        server: widget.server,
        token: widget.auth.user!.token,
        existing: room,
        onSaved: (updated) => setState(() {
          final index = _rooms.indexWhere((r) => r.id == updated.id);
          if (index != -1) _rooms[index] = updated;
        }),
      ),
    );
  }

  Future<void> _handleDelete(CallRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete room'),
        content: Text('Are you sure you want to delete "${room.roomName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await room.delete(widget.server, widget.auth.user!.token);
      if (mounted) setState(() => _rooms.removeWhere((r) => r.id == room.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete room.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calls')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
              : _rooms.isEmpty
                  ? const Center(child: Text('No rooms available.'))
                  : RefreshIndicator(
                      onRefresh: _loadRooms,
                      child: ListView.separated(
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          final isHost = room.host == widget.auth.user!.userId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(Icons.video_call_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
                            ),
                            title: Text(room.roomName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(room.formattedDate),
                                Text(
                                  'Host: ${room.hostUsername ?? 'Unknown'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isHost) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _showEditSheet(room),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
                                    onPressed: () => _handleDelete(room),
                                  ),
                                ],
                                FilledButton.icon(
                                  onPressed: () => _joinRoom(room),
                                  icon: const Icon(Icons.call, size: 16),
                                  label: const Text('Join'),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
                    ),
      floatingActionButton: widget.auth.user is Employer
          ? FloatingActionButton(
              onPressed: _showCreateSheet,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _RoomFormSheet extends StatefulWidget {
  final Server server;
  final String token;
  final CallRoom? existing;
  final void Function(CallRoom room) onSaved;

  const _RoomFormSheet({
    required this.server,
    required this.token,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends State<_RoomFormSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _meetingDate;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.roomName;
      _descriptionController.text = widget.existing!.description;
      _meetingDate = DateTime.parse(widget.existing!.meetingDate).toLocal();
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingDate ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _meetingDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _handleSubmit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Room name is required.');
      return;
    }
    if (_meetingDate == null) {
      setState(() => _error = 'Meeting date is required.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final CallRoom saved;
      if (widget.existing == null) {
        saved = await CallRoom.create(
          widget.server,
          widget.token,
          roomName: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          meetingDate: _meetingDate!,
        );
      } else {
        saved = await widget.existing!.update(
          widget.server,
          widget.token,
          roomName: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          meetingDate: _meetingDate!,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved(saved);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save room.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Create room' : 'Edit room',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Room name',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_meetingDate != null ? _formatDate(_meetingDate!) : 'Pick meeting date & time'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.existing == null ? 'Create' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
