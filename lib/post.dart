import 'server_api.dart';

class Post {
  final int id;
  final int user;
  final String username;
  final String fullName;
  final String? avatar;
  final String content;
  final int likesCount;
  final int commentsCount;
  final String createdAt;
  final String updatedAt;
  final List<PostImage> images;
  final bool isLikedByMe;

  const Post({
    required this.id,
    required this.user,
    required this.username,
    required this.fullName,
    required this.avatar,
    required this.content,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
    required this.isLikedByMe,
  });

  factory Post.fromJson(Map<String, dynamic> json, Server server) {
    final serverHost = Uri.parse(server.getServerUrl()!).host;

    final rawAvatar = json['avatar'] as String?;
    final avatar = rawAvatar != null
        ? rawAvatar.replaceFirst('localhost', serverHost)
        : null;

    return Post(
      id: json['id'] as int,
      user: json['user'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String? ?? json['username'] as String,
      avatar: avatar,
      content: json['content'] as String,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      images: (json['images'] as List? ?? [])
        .map((i) => PostImage.fromJson(i, server))
        .toList(),
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
    );
  }

  static Future<List<Post>> fetchAllPosts(Server server, String token) async {
    final list = await server.sendGetList('/api/posts/', token: token);
    return list.map((p) => Post.fromJson(p, server)).toList();
  }

  static Future<Post> fetchPost(Server server, String token, int postId) async {
    final data = await server.sendGet('/api/posts/$postId/', token: token);
    return Post.fromJson(data, server);
  }

  static Future<Post> createPost(Server server, String token, {required String content}) async {
    final data = await server.sendPost('/api/posts/', {'content': content}, token: token);
    return Post.fromJson(data, server);
  }

  Future<Post> updatePost(Server server, String token, {required String content}) async {
    final data = await server.sendPatch('/api/posts/$id/', {'content': content}, token: token);
    return Post.fromJson(data, server);
  }

  Future<void> deletePost(Server server, String token) async {
    await server.sendDelete('/api/posts/$id/', token: token);
  }

  Future<void> likePost(Server server, String token) async {
    await server.sendPost('/api/posts/$id/like/', {}, token: token);
  }

  Future<void> unlikePost(Server server, String token) async {
    await server.sendDelete('/api/posts/$id/like/', token: token);
  }
}

class PostImage {
  final int id;
  final String imageUrl;
  final String createdAt;
  final int post;

  const PostImage({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    required this.post,
  });

  factory PostImage.fromJson(Map<String, dynamic> json, Server server) {
    final serverHost = Uri.parse(server.getServerUrl()!).host;
    final rawUrl = json['image'] as String;

    return PostImage(
      id: json['id'] as int,
      imageUrl: rawUrl.replaceFirst('localhost', serverHost),
      createdAt: json['created_at'] as String,
      post: json['post'] as int,
    );
  }

  static Future<PostImage> uploadImage(
    Server server,
    String token,
    int postId,
    List<int> fileBytes,
    String filename,
  ) async {
    final data = await server.sendMultipart(
      '/api/posts/$postId/images/',
      'image',
      fileBytes,
      filename,
      token: token,
    );
    return PostImage.fromJson(data, server);
  }

  Future<void> deleteImage(Server server, String token) async {
    await server.sendDelete('/api/posts/$post/images/$id/', token: token);
  }
}

class Comment {
  final int id;
  final int user;
  final String? username;
  final String? fullName;
  final String? avatar;
  final int post;
  final String content;
  final String createdAt;
  final String updatedAt;

  const Comment({
    required this.id,
    required this.user,
    required this.username,
    required this.fullName,
    required this.avatar,
    required this.post,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json, Server server) {
    final serverHost = Uri.parse(server.getServerUrl()!).host;

    final rawAvatar = json['avatar'] as String?;
    final avatar = rawAvatar != null
        ? rawAvatar.replaceFirst('localhost', serverHost)
        : null;

    return Comment(
      id: json['id'] as int,
      user: json['user'] as int,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatar: avatar,
      post: json['post'] as int,
      content: json['content'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  static Future<List<Comment>> fetchCommentsForPost(Server server, String token, int postId) async {
    final list = await server.sendGetList('/api/posts/$postId/comments/', token: token);
    return list.map((c) => Comment.fromJson(c, server)).toList();
  }

  static Future<Comment> createComment(Server server, String token, int postId, {required String content}) async {
    final data = await server.sendPost('/api/posts/$postId/comments/', {'content': content}, token: token);
    return Comment.fromJson(data, server);
  }

  Future<Comment> updateComment(Server server, String token, {required String content}) async {
    final data = await server.sendPatch('/api/posts/$post/comments/$id/', {'content': content}, token: token);
    return Comment.fromJson(data, server);
  }

  Future<void> deleteComment(Server server, String token) async {
    await server.sendDelete('/api/posts/$post/comments/$id/', token: token);
  }
}