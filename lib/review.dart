import '../server_api.dart';

class Review {
  final int id;
  final int? owner;
  final String? ownerUsername;
  final String? ownerFullName;
  final String? ownerAvatar;
  final String content;
  final int score;
  final String createdAt;
  final bool edited;

  const Review({
    required this.id,
    required this.owner,
    required this.ownerUsername,
    required this.ownerFullName,
    required this.ownerAvatar,
    required this.content,
    required this.score,
    required this.createdAt,
    required this.edited,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      owner: json['owner'] as int?,
      ownerUsername: json['owner_username'] as String?,
      ownerFullName: json['owner_full_name'] as String?,
      ownerAvatar: json['owner_avatar'] as String?,
      content: json['content'] as String? ?? '',
      score: json['score'] as int,
      createdAt: json['created_at'] as String,
      edited: json['edited'] as bool,
    );
  }

  // Fetches all reviews for a given employer profile
  static Future<List<Review>> fetchReviewsForEmployer(Server server, String token, int employerId) async {
    final list = await server.sendGetList('/api/reviews/$employerId/', token: token);
    return list.map((r) => Review.fromJson(r)).toList();
  }

  // Creates a review for the given employer profile ID
  static Future<Review> create(
    Server server,
    String token,
    int employerId, {
    required int score,
    String content = '',
  }) async {
    final data = await server.sendPost('/api/reviews/$employerId/', {
      'score': score,
      'content': content,
    }, token: token);
    return Review.fromJson(data);
  }

  // Updates a review
  static Future<Review> update(
    Server server,
    String token,
    int employerId,
    int reviewId, {
    required int score,
    String content = '',
  }) async {
    final data = await server.sendPut('/api/reviews/$employerId/$reviewId/', {
      'score': score,
      'content': content,
    }, token: token);
    return Review.fromJson(data);
  }

  // Deletes a review
  static Future<void> delete(
    Server server,
    String token,
    int employerId,
    int reviewId,
  ) async {
    await server.sendDelete('/api/reviews/$employerId/$reviewId/', token: token);
  }
}

// Fetches all employer profiles for the reviews screen
Future<List<Map<String, dynamic>>> fetchEmployersList(Server server, String token) async {
  final list = await server.sendGetList('/api/employers/', token: token);
  return list.cast<Map<String, dynamic>>();
}
