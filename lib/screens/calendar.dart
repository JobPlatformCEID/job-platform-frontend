import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../server_api/auth.dart';
import '../server_api/server.dart';
import '../server_api/calls.dart';
import 'call_room_screen.dart';

const _ghBg = Color(0xFF0D1117);
const _ghSurface = Color(0xFF161B22);
const _ghSurfaceAlt = Color(0xFF21262D);
const _ghBorder = Color(0xFF30363D);
const _ghBorderMuted = Color(0xFF21262D);
const _ghAccent = Color(0xFF58A6FF);
const _ghAccentMuted = Color(0xFF1F3A5F);
const _ghTextPrimary = Color(0xFFE6EDF3);
const _ghTextSecondary = Color(0xFF8B949E);
const _ghTextMuted = Color(0xFF484F58);
const _ghPurple = Color(0xFFBC8CFF);
const _ghPurpleMuted = Color(0xFF2D1F6E);
const _ghGreen = Color(0xFF3FB950);
const _ghRed = Color(0xFFF85149);
const _ghShadow = Color(0xFF010409);

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not join call.', style: TextStyle(color: _ghTextPrimary)),
            backgroundColor: _ghSurfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _ghBorder)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ghBg,
      appBar: AppBar(
        backgroundColor: _ghSurface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ghTextPrimary,
        iconTheme: const IconThemeData(color: _ghTextPrimary),
        title: const Text('Meetings', style: TextStyle(color: _ghTextPrimary, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _ghBorder),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  color: _ghAccent,
                  backgroundColor: _ghSurfaceAlt,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: _buildCalendar(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(height: 1, color: _ghBorder),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: _selectedDay == null
                            ? _buildEmptyState()
                            : _selectedRooms.isEmpty
                                ? _buildNoMeetingsState()
                                : _buildMeetingsList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _ghAccent, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Loading meetings...', style: TextStyle(color: _ghTextSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: _ghRed),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: _ghRed, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadRooms,
              icon: const Icon(Icons.refresh, size: 18, color: _ghAccent),
              label: const Text('Retry', style: TextStyle(color: _ghAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _ghBorder),
                backgroundColor: _ghSurfaceAlt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: _ghSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ghBorder),
      ),
      clipBehavior: Clip.antiAlias,
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
        headerStyle: const HeaderStyle(
          titleCentered: true,
          titleTextStyle: TextStyle(color: _ghTextPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          formatButtonVisible: true,
          formatButtonDecoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: _ghBorder)),
            borderRadius: BorderRadius.all(Radius.circular(6)),
            color: _ghSurfaceAlt,
          ),
          formatButtonTextStyle: TextStyle(color: _ghTextSecondary, fontSize: 12),
          leftChevronIcon: Icon(Icons.chevron_left, color: _ghTextSecondary),
          rightChevronIcon: Icon(Icons.chevron_right, color: _ghTextSecondary),
          headerPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: _ghAccentMuted,
            shape: BoxShape.circle,
            border: Border.all(color: _ghAccent, width: 1.5),
          ),
          todayTextStyle: const TextStyle(color: _ghAccent, fontWeight: FontWeight.w600, fontSize: 13),
          selectedDecoration: const BoxDecoration(color: _ghAccent, shape: BoxShape.circle),
          selectedTextStyle: const TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w700, fontSize: 13),
          markerDecoration: const BoxDecoration(color: _ghGreen, shape: BoxShape.circle),
          markerSize: 6,
          markersMaxCount: 3,
          markersAnchor: 0.85,
          outsideDaysVisible: true,
          outsideTextStyle: const TextStyle(color: _ghTextMuted, fontSize: 13),
          defaultTextStyle: const TextStyle(color: _ghTextPrimary, fontSize: 13),
          weekendTextStyle: const TextStyle(color: _ghTextPrimary, fontSize: 13),
          cellMargin: const EdgeInsets.all(6),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: _ghTextSecondary, fontWeight: FontWeight.w500, fontSize: 12),
          weekendStyle: TextStyle(color: _ghTextSecondary, fontWeight: FontWeight.w500, fontSize: 12),
          decoration: BoxDecoration(color: _ghSurfaceAlt),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _ghSurfaceAlt, shape: BoxShape.circle, border: Border.all(color: _ghBorder)),
              child: const Icon(Icons.calendar_today_rounded, size: 36, color: _ghAccent),
            ),
            const SizedBox(height: 20),
            const Text('Select a date', style: TextStyle(color: _ghTextPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Tap any day on the calendar to view\nscheduled meetings',
              style: TextStyle(color: _ghTextSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMeetingsState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _ghSurfaceAlt, shape: BoxShape.circle, border: Border.all(color: _ghBorder)),
              child: const Icon(Icons.event_busy_rounded, size: 36, color: _ghTextSecondary),
            ),
            const SizedBox(height: 20),
            const Text('No meetings scheduled', style: TextStyle(color: _ghTextPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'There are no meetings on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
              style: const TextStyle(color: _ghTextSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsList() {
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
    final isHost = room.host == currentUserId;
    final dt = DateTime.parse(room.meetingDate!).toLocal();
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _ghSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ghBorder),
        boxShadow: const [BoxShadow(color: _ghShadow, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onJoin,
          borderRadius: BorderRadius.circular(12),
          splashColor: _ghAccent.withOpacity(0.05),
          highlightColor: _ghAccent.withOpacity(0.03),
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
                        color: _ghAccentMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _ghAccent.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.video_call_rounded, color: _ghAccent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.roomName,
                            style: const TextStyle(color: _ghTextPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 13, color: _ghTextSecondary),
                              const SizedBox(width: 4),
                              Text(timeStr, style: const TextStyle(color: _ghTextSecondary, fontSize: 12)),
                              if (room.hostUsername != null) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.person_rounded, size: 13, color: _ghTextSecondary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Host: ${room.hostUsername!}',
                                    style: const TextStyle(color: _ghTextSecondary, fontSize: 12),
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
                        color: isHost ? _ghPurpleMuted : _ghSurfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isHost ? _ghPurple.withOpacity(0.4) : _ghBorder),
                      ),
                      child: Text(
                        isHost ? 'Host' : 'You',
                        style: TextStyle(
                          color: isHost ? _ghPurple : _ghTextSecondary,
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
                      color: _ghBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _ghBorderMuted),
                    ),
                    child: Text(
                      room.description,
                      style: const TextStyle(color: _ghTextSecondary, height: 1.5, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Color(0xFF0D1117)),
                    label: const Text(
                      'Join Meeting',
                      style: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ghAccent,
                      foregroundColor: const Color(0xFF0D1117),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}