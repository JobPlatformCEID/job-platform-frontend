import 'server.dart';

class Conversation {
  final int id;
  final int? otherUserId;
  final String? otherUsername;
  final String? otherFullName;
  final String? otherUserAvatar;
  final Message? lastMessage;
  final Map<int, int> readStatuses;
  final String createdAt;

  const Conversation({
    required this.id,
    this.otherUserId,
    this.otherUsername,
    this.otherFullName,
    this.otherUserAvatar,
    this.lastMessage,
    this.readStatuses = const {},
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final otherUser = json['other_user'] as Map<String, dynamic>?;
    final lastMessageJson = json['last_message'] as Map<String, dynamic>?;
    return Conversation(
      id: json['id'] as int,
      otherUserId: otherUser?['id'] as int?,
      otherUsername: otherUser?['username'] as String?,
      otherFullName: otherUser?['full_name'] as String?,
      otherUserAvatar: otherUser?['avatar'] as String?,
      lastMessage: lastMessageJson != null ? Message.fromJson(lastMessageJson) : null,
      readStatuses: (json['read_statuses'] as Map<String, dynamic>?) 
        ?.map((k, v) => MapEntry(int.parse(k), v as int)) ?? {},
      createdAt: json['created_at'] as String,
    );
  }

  static Future<List<Conversation>> fetchAllConversations(Server server, String token) async {
    final list = await server.sendGetList('/api/conversations/', token: token);
    return list.map((c) => Conversation.fromJson(c)).toList();
  }

  static Future<Conversation> createConversation(Server server, String token, int userId) async {
    final data = await server.sendPost('/api/conversations/', {'user_id': userId}, token: token);
    return Conversation.fromJson(data);
  }

  Future<void> deleteConversation(Server server, String token) async {
    await server.sendDelete('/api/conversations/$id/', token: token);
  }
}

class Message {
  final int id;
  final int sender;
  final String? senderUsername;
  final int conversation;
  final String content;
  final String createdAt;

  const Message({
    required this.id,
    required this.sender,
    this.senderUsername,
    required this.conversation,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      sender: json['sender'] as int,
      senderUsername: json['sender_username'] as String?,
      conversation: json['conversation'] as int,
      content: json['content'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  static Future<List<Message>> fetchAllMessages(Server server, String token, int conversationId) async {
    final list = await server.sendGetList('/api/conversations/$conversationId/messages/', token: token);
    return list.map((m) => Message.fromJson(m)).toList();
  }

  Future<void> deleteMessage(Server server, String token) async {
    await server.sendDelete('/api/conversations/$conversation/messages/$id/', token: token);
  }
}
