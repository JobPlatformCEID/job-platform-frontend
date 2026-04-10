import 'server.dart';

class CallRoom {
  final int id;
  final String roomName;
  final String description;
  final String meetingDate;
  final int host;
  final String? hostUsername;
  final String createdAt;

  const CallRoom({
    required this.id,
    required this.roomName,
    required this.description,
    required this.meetingDate,
    required this.host,
    required this.hostUsername,
    required this.createdAt,
  });

  factory CallRoom.fromJson(Map<String, dynamic> json) {
    return CallRoom(
      id: json['id'] as int,
      roomName: json['room_name'] as String,
      description: json['description'] as String? ?? '',
      meetingDate: json['meeting_date'] as String,
      host: json['host'] as int,
      hostUsername: json['host_username'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  static Future<List<CallRoom>> fetchAll(Server server, String token) async {
    final list = await server.sendGetList('/api/calls/', token: token);
    return list.map((r) => CallRoom.fromJson(r)).toList();
  }

  static Future<CallRoom> create(
    Server server,
    String token, {
    required String roomName,
    required String description,
    required DateTime meetingDate,
  }) async {
    final data = await server.sendPost('/api/calls/', {
      'room_name': roomName,
      'description': description,
      'meeting_date': meetingDate.toUtc().toIso8601String(),
    }, token: token);
    return CallRoom.fromJson(data);
  }

  Future<CallRoom> update(
    Server server,
    String token, {
    required String roomName,
    required String description,
    required DateTime meetingDate,
  }) async {
    final data = await server.sendPut('/api/calls/$id/', {
      'room_name': roomName,
      'description': description,
      'meeting_date': meetingDate.toUtc().toIso8601String(),
    }, token: token);
    return CallRoom.fromJson(data);
  }

  Future<void> delete(Server server, String token) async {
    await server.sendDelete('/api/calls/$id/', token: token);
  }

  Future<CallToken> getToken(Server server, String token) async {
    final data = await server.sendPost('/api/calls/$id/token/', {}, token: token);
    return CallToken.fromJson(data);
  }

  String get formattedDate {
    final date = DateTime.parse(meetingDate).toLocal();
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class CallToken {
  final String token;
  final String url;
  final String roomName;
  final bool isHost;

  const CallToken({
    required this.token,
    required this.url,
    required this.roomName,
    required this.isHost,
  });

  factory CallToken.fromJson(Map<String, dynamic> json) {
    return CallToken(
      token: json['token'] as String,
      url: json['url'] as String,
      roomName: json['room_name'] as String,
      isHost: json['is_host'] as bool,
    );
  }
}
