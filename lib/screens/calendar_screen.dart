import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../auth.dart';
import '../server_api.dart';
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

  final DateTime _today = DateTime.now();
  late DateTime _focusedDay;
  late DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  late final LinkedHashMap<DateTime, List<CallRoom>> _events;
  List<CallRoom> _selectedRooms = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = _today;
    _selectedDay = _dateOnly(_today);
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
    } catch (e) {
      if (mounted) {
        final msg = e is ServerException ? e.detail : 'Could not join call.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(cs)
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: _buildCalendar(cs),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Divider(height: 1, color: cs.outlineVariant),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: _selectedDay == null
                            ? _buildEmptyState(cs)
                            : _selectedRooms.isEmpty
                                ? _buildNoMeetingsState(cs)
                                : _buildMeetingsList(cs),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadRooms,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(ColorScheme cs) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TableCalendar<CallRoom>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _eventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          onFormatChanged: (format) => setState(() => _calendarFormat = format),
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
          onDaySelected: _onDaySelected,
          headerStyle: HeaderStyle(
            titleCentered: true,
            titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
            formatButtonDecoration: BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: cs.outline)),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              color: cs.surfaceContainerHighest,
            ),
            formatButtonTextStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            leftChevronIcon: Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
            rightChevronIcon: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            headerPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary, width: 1.5),
            ),
            todayTextStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w600, fontSize: 13),
            selectedDecoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            selectedTextStyle: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 13),
            markerDecoration: BoxDecoration(color: cs.tertiary, shape: BoxShape.circle),
            markerSize: 6,
            markersMaxCount: 3,
            markersAnchor: 0.85,
            outsideDaysVisible: true,
            outsideTextStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 13),
            defaultTextStyle: TextStyle(color: cs.onSurface, fontSize: 13),
            weekendTextStyle: TextStyle(color: cs.onSurface, fontSize: 13),
            cellMargin: const EdgeInsets.all(6),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: 12),
            weekendStyle: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: 12),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('Select a date', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap any day on the calendar to view\nscheduled meetings',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMeetingsState(ColorScheme cs) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_busy_rounded, size: 36, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text('No meetings scheduled', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'There are no meetings on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsList(ColorScheme cs) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _MeetingCard(
          room: _selectedRooms[index],
          currentUserId: widget.auth.user!.userId,
          onJoin: () => _joinRoom(_selectedRooms[index]),
        ),
        childCount: _selectedRooms.length,
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
    final cs = Theme.of(context).colorScheme;
    final isHost = room.host == currentUserId;
    final dt = DateTime.parse(room.meetingDate!).toLocal();
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onJoin,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.video_call_rounded, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.roomName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(timeStr, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                            if (room.hostUsername != null) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.person_rounded, size: 13, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Host: ${room.hostUsername!}',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHost ? cs.secondaryContainer : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isHost ? 'Host' : 'You',
                      style: TextStyle(
                        color: isHost ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (room.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    room.description,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.5, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Join Meeting', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}