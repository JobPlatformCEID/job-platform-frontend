import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../auth.dart';
import '../server.dart';
import '../theme/app_theme.dart';
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not join call.', style: TextStyle(color: AppTheme.textPrimary)),
            backgroundColor: AppTheme.surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        title: Text('Meetings', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.surfaceAlt,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: _buildCalendar(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(height: 1, color: AppTheme.divider),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Loading meetings...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: AppTheme.error, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadRooms,
              icon: Icon(Icons.refresh, size: 18, color: AppTheme.primary),
              label: Text('Retry', style: TextStyle(color: AppTheme.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.divider),
                backgroundColor: AppTheme.surfaceAlt,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
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
        headerStyle: HeaderStyle(
          titleCentered: true,
          titleTextStyle: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          formatButtonVisible: true,
          formatButtonDecoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: AppTheme.divider)),
            borderRadius: BorderRadius.all(Radius.circular(6)),
            color: AppTheme.surfaceAlt,
          ),
          formatButtonTextStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.textSecondary),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          headerPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryDark.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary, width: 1.5),
          ),
          todayTextStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
          selectedDecoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          selectedTextStyle: TextStyle(color: AppTheme.background, fontWeight: FontWeight.w700, fontSize: 13),
          markerDecoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
          markerSize: 6,
          markersMaxCount: 3,
          markersAnchor: 0.85,
          outsideDaysVisible: true,
          outsideTextStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          defaultTextStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          weekendTextStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          cellMargin: EdgeInsets.all(6),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
          weekendStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
          decoration: BoxDecoration(color: AppTheme.surfaceAlt),
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
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: AppTheme.divider)),
              child: Icon(Icons.calendar_today_rounded, size: 36, color: AppTheme.primary),
            ),
            SizedBox(height: 20),
            Text('Select a date', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'Tap any day on the calendar to view\nscheduled meetings',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: AppTheme.divider)),
              child: Icon(Icons.event_busy_rounded, size: 36, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 20),
            Text('No meetings scheduled', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'There are no meetings on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onJoin,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppTheme.primary.withValues(alpha: 0.05),
          highlightColor: AppTheme.primary.withValues(alpha: 0.03),
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
                        color: AppTheme.primaryDark.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.video_call_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.roomName,
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textSecondary),
                              SizedBox(width: 4),
                              Text(timeStr, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              if (room.hostUsername != null) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.person_rounded, size: 13, color: AppTheme.textSecondary),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Host: ${room.hostUsername!}',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isHost ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isHost ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.divider),
                      ),
                      child: Text(
                        isHost ? 'Host' : 'You',
                        style: TextStyle(
                          color: isHost ? AppTheme.accent : AppTheme.textSecondary,
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
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      room.description,
                      style: TextStyle(color: AppTheme.textSecondary, height: 1.5, fontSize: 13),
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
                      style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.background,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 13),
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