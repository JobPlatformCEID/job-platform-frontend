import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../auth.dart';
import '../server.dart';
import '../calls.dart';
import 'call_room_screen.dart';

int _getHashCode(DateTime key) =>
    key.day * 1000000 + key.month * 10000 + key.year;

class CalendarScreen extends StatefulWidget {
  final Auth auth;
  final Server server;

  const CalendarScreen({super.key, required this.auth, required this.server});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isLoading = true;
  String? _error;

  // table_calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Events map: date → list of CallRooms scheduled on that date.
  late final LinkedHashMap<DateTime, List<CallRoom>> _events;

  // The meetings to show under the calendar for the selected day
  List<CallRoom> _selectedRooms = [];

  @override
  void initState() {
    super.initState();
    _events = LinkedHashMap(equals: isSameDay, hashCode: _getHashCode);
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final all = await CallRoom.fetchAll(widget.server, widget.auth.user!.token);
      final scheduled = all.where((r) => r.meetingDate != null).toList();

      final newEvents = LinkedHashMap<DateTime, List<CallRoom>>(
        equals: isSameDay,
        hashCode: _getHashCode,
      );
      for (final room in scheduled) {
        final day = _dateOnly(DateTime.parse(room.meetingDate!).toLocal());
        newEvents.update(day, (list) => list..add(room), ifAbsent: () => [room]);
      }

      if (mounted) {
        setState(() {
          _events.clear();
          _events.addAll(newEvents);
          if (_selectedDay != null) {
            _selectedRooms = _eventsForDay(_selectedDay!);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _error = 'Could not load meetings.'; });
    }
  }

  List<CallRoom> _eventsForDay(DateTime day) => _events[day] ?? [];

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedRooms = _eventsForDay(selectedDay);
      });
    } else {
      setState(() {
        _selectedDay = null;
        _selectedRooms = [];
      });
    }
  }

  Future<void> _joinRoom(CallRoom room) async {
    try {
      if (!room.isParticipant) {
        await room.addParticipant(widget.server, widget.auth.user!.token);
      }
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not join call.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Calendar')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: TextStyle(color: colorScheme.error)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _loadRooms,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: Column(
                    children: [
                      TableCalendar<CallRoom>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: _eventsForDay,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        onFormatChanged: (format) =>
                            setState(() => _calendarFormat = format),
                        onPageChanged: (focusedDay) =>
                            _focusedDay = focusedDay,
                        onDaySelected: _onDaySelected,
                        headerStyle: HeaderStyle(
                          formatButtonDecoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          formatButtonTextStyle:
                              TextStyle(color: colorScheme.onSurface),
                          titleCentered: true,
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          markerDecoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          markerSize: 6,
                          markersMaxCount: 3,
                          outsideDaysVisible: true,
                          outsideTextStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.35),
                          ),
                        ),
                      ),

                      const Divider(height: 1),

                      Expanded(
                        child: _selectedDay == null
                            ? Center(
                                child: Text(
                                  'Tap a day to see meetings',
                                  style: TextStyle(
                                      color: colorScheme.onSurfaceVariant),
                                ),
                              )
                            : _selectedRooms.isEmpty
                                ? Center(
                                    child: Text(
                                      'No meetings on this day',
                                      style: TextStyle(
                                          color: colorScheme.onSurfaceVariant),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    itemCount: _selectedRooms.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) =>
                                        _MeetingCard(
                                      room: _selectedRooms[index],
                                      currentUserId:
                                          widget.auth.user!.userId,
                                      onJoin: () =>
                                          _joinRoom(_selectedRooms[index]),
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final CallRoom room;
  final int currentUserId;
  final VoidCallback onJoin;

  const _MeetingCard({
    required this.room,
    required this.currentUserId,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHost = room.host == currentUserId;
    final dt = DateTime.parse(room.meetingDate!).toLocal();
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.video_call_outlined,
                      color: colorScheme.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    room.roomName,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isHost
                        ? colorScheme.secondaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isHost ? 'Host' : 'Participant',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isHost
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            //Meta: time + host name
            Row(
              children: [
                Icon(Icons.access_time_outlined,
                    size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(timeStr,
                    style: Theme.of(context).textTheme.bodySmall),
                if (room.hostUsername != null) ...[
                  const SizedBox(width: 14),
                  Icon(Icons.person_outline,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    room.hostUsername!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),

            // ── Optional description ──
            if (room.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                room.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],

            const SizedBox(height: 14),

            FilledButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.call, size: 16),
              label: const Text('Join Call'),
            ),
          ],
        ),
      ),
    );
  }
}