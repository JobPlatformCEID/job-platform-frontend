import 'package:logging/logging.dart';
import 'server.dart';

abstract class User {
  final Server server;
  final String token;
  final String username;
  final int userId;
  String firstName;
  String lastName;
  String email;
  String? avatarUrl;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : username;
  }

  // Constructor
  User({
    required this.server,
    required this.username,
    required this.token,
    required this.userId,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.avatarUrl,
  });

  // Get all user info from the server
  Future<void> fetchMe() async {
    final data = await server.sendGet('/api/users/me/', token: token);
    firstName = data['first_name'] as String? ?? '';
    lastName = data['last_name'] as String? ?? '';
    email = data['email'] as String? ?? '';
    avatarUrl = data['avatar'] as String?;
  }

  // Updates user info
  Future<void> updateMe() async {
    await server.sendPatch('/api/users/me/', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
    }, token: token);
  }

  // Uploads an avatar for the current user
  Future<void> updateAvatar(List<int> bytes, String filename) async {
    await server.sendMultipartPatch(
      '/api/users/me/',
      'avatar',
      bytes,
      filename,
      token: token,
    );
    await fetchMe();
  }

  static Future<List<Map<String, dynamic>>> searchUsers(Server server, String token, String q) async {
    final list = await server.sendGetList('/api/users/?search=${Uri.encodeComponent(q)}', token: token);
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> fetchProfile();
  Future<void> updateProfile();
}

class Candidate extends User {
  int? candidateProfileId;
  String phone = '';
  String location = '';
  String bio = '';
  String? cvUrl;
//  double score = 0;

  // Constructor
  Candidate({
    required super.server,
    required super.username,
    required super.token,
    required super.userId,
  });

  @override
  Future<void> fetchProfile() async {
    final data = await server.sendGet('/api/candidates/me/', token: token);
    candidateProfileId = data['id'] as int;
    phone = data['phone'] as String? ?? '';
    location = data['location'] as String? ?? '';
    bio = data['bio'] as String? ?? '';
    cvUrl = data['cv'] as String?;
//  score = (data['score'] as num).toDouble();
  }

  @override
  Future<void> updateProfile() async {
    await server.sendPut('/api/candidates/me/', {
      'phone': phone,
      'location': location,
      'bio': bio,
    }, token: token);
  }

  // Uploads a CV for the current candidate
  Future<void> uploadCV(List<int> bytes, String filename) async {
    await server.sendMultipartPatch(
      '/api/candidates/me/',
      'cv',
      bytes,
      filename,
      token: token,
    );
    // Mostly for profile screen to see the new cv imideatly
    await fetchProfile();
  }
}

class Employer extends User {
  int? employerProfileId;
  String companyName = '';
  String description = '';
  String location = '';
  String website = '';

  // Constructor
  Employer({
    required super.server,
    required super.username,
    required super.token,
    required super.userId,
    });

  @override
  Future<void> fetchProfile() async {
    final data = await server.sendGet('/api/employers/me/', token: token);
    employerProfileId = data['id'] as int;
    companyName = data['company_name'] as String? ?? '';
    description = data['description'] as String? ?? '';
    location = data['location'] as String? ?? '';
    website = data['website'] as String? ?? '';
  }

  @override
  Future<void> updateProfile() async {
    await server.sendPut('/api/employers/me/', {
      'company_name': companyName,
      'description': description,
      'location': location,
      'website': website,
    }, token: token);
  }
}
